require "test_helper"

class HardeningTest < Minitest::Test
  def setup
    @user = Object.new
    @post = Post.new(@user, 1)
    @controller = PostsController.new(@user, { action: 'update', controller: 'posts' })
  end

  # verify_authorized names the controller and the action

  def test_verify_authorized_message_names_the_controller_class_and_action
    error = assert_raises(Banken::AuthorizationNotPerformedError) { @controller.verify_authorized }

    assert_equal "PostsController#update did not call authorize! or skip_authorization", error.message
  end

  def test_verify_authorized_message_without_an_action_names_only_the_controller
    controller = PostsController.new(@user, {})
    error = assert_raises(Banken::AuthorizationNotPerformedError) { controller.verify_authorized }

    assert_equal "PostsController did not call authorize! or skip_authorization", error.message
  end

  # banken_param_key accepts Symbols and rejects nil

  def test_permitted_attributes_accepts_a_symbol_record_as_the_params_key
    params = ActionController::Parameters.new(controller: "posts", action: "create", post: { votes: 4, admin: true })
    permitted = PostsController.new(@user, params).permitted_attributes(:post)

    assert_equal({ "votes" => 4 }, permitted.to_h)
  end

  def test_permitted_attributes_rejects_a_nil_record_with_a_clear_error
    params = ActionController::Parameters.new(controller: "posts", action: "create", nil_class: { votes: 4 })
    error = assert_raises(ArgumentError) { PostsController.new(@user, params).permitted_attributes(nil) }

    assert_includes error.message, "nil"
  end

  # NotAuthorizedError tolerates non-Hash arguments

  def test_not_authorized_error_raised_with_nil_uses_the_class_name_as_message
    error = assert_raises(Banken::NotAuthorizedError) { raise Banken::NotAuthorizedError, nil }

    assert_equal "Banken::NotAuthorizedError", error.message
    assert_nil error.query
  end

  def test_not_authorized_error_accepts_a_symbol_message
    error = Banken::NotAuthorizedError.new(:nope)

    assert_equal "nope", error.message
  end

  # queries must be defined by the loyalty, never inherited from Object

  def test_authorize_bang_denies_actions_that_match_predicates_every_object_has
    # ActiveSupport defines present? and duplicable? on Object and both return true.
    %w[present duplicable nil frozen].each do |action|
      controller = PostsController.new(@user, { action: action, controller: 'posts' })
      error = assert_raises(Banken::NotDefinedError, "action #{action}") { controller.authorize!(@post) }
      assert_includes error.message, "PostsLoyalty##{action}?"
    end
  end

  def test_authorize_bang_raises_not_defined_error_for_an_undefined_query
    @controller.params[:action] = 'update_all'
    error = assert_raises(Banken::NotDefinedError) { @controller.authorize!(@post) }

    assert_equal "PostsLoyalty#update_all? is not defined", error.message
  end

  def test_authorize_bang_accepts_queries_defined_in_a_loyalty_module_or_superclass
    assert_equal true, PostsController.new(@user, { action: 'show', controller: 'posts' }).authorize!(@post)
  end

  # on a Rails controller, params never substitute for action_name / controller_path

  def test_rails_hosts_do_not_fall_back_to_params_for_the_controller_name
    anonymous = Class.new(PostsController) do
      def action_name; "index"; end
      def controller_path; nil; end
    end
    controller = anonymous.new(@user, { action: "index", controller: "posts" })
    error = assert_raises(Banken::NotDefinedError) { controller.loyalty }

    assert_includes error.message, "no controller_path"
  end

  def test_rails_hosts_do_not_fall_back_to_params_for_the_action_name
    unprocessed = Class.new(PostsController) do
      def action_name; nil; end
      def controller_path; "posts"; end
    end
    controller = unprocessed.new(@user, { action: "destroy", controller: "posts" })

    assert_raises(Banken::Error) { controller.authorize!(@post) }
  end

  # permitted_attributes with a scalar or array value is a 400, not a 500

  def test_permitted_attributes_raises_parameter_missing_for_a_scalar_value
    params = ActionController::Parameters.new(controller: "posts", action: "update", post: "scalar")

    assert_raises(ActionController::ParameterMissing) { PostsController.new(@user, params).permitted_attributes(@post) }
  end

  def test_permitted_attributes_raises_parameter_missing_for_an_array_value
    params = ActionController::Parameters.new(controller: "posts", action: "update", post: ["a", "b"])

    assert_raises(ActionController::ParameterMissing) { PostsController.new(@user, params).permitted_attributes(@post) }
  end

  # the helper names are known

  def test_hidden_actions_lists_every_public_helper
    assert_equal Banken::Authorization.public_instance_methods(false).map(&:to_s).sort, Banken::Authorization::HIDDEN_ACTIONS
    assert Banken::Authorization::HIDDEN_ACTIONS.frozen?
  end
end
