require "test_helper"

# Unit tests for the controller mixin using the fake PostsController.
# These cover behaviour the original suite left implicit.
class ControllerHelpersTest < Minitest::Test
  class CustomUserController < PostsController
    def banken_user
      :custom_user
    end
  end

  def setup
    @user = Object.new
    @post = Post.new(@user, 1)
    @controller = PostsController.new(@user, { action: 'update', controller: 'posts' })
  end

  # loyalty resolution from params

  def test_loyalty_uses_params_controller_when_no_name_is_given
    assert_instance_of PostsLoyalty, @controller.loyalty(@post)
  end

  def test_loyalty_resolves_namespaced_controller_paths_from_params
    controller = PostsController.new(@user, { action: 'index', controller: 'admin/posts' })

    assert_instance_of Admin::PostsLoyalty, controller.loyalty
  end

  def test_loyalty_accepts_an_explicit_namespaced_controller_name
    assert_instance_of Admin::PostsLoyalty, @controller.loyalty(@post, 'admin/posts')
  end

  def test_loyalty_accepts_an_explicit_symbol_controller_name
    assert_instance_of PostsLoyalty, @controller.loyalty(@post, :posts)
  end

  def test_loyalty_passes_banken_user_rather_than_current_user
    controller = CustomUserController.new(@user, { action: 'update', controller: 'posts' })

    assert_equal :custom_user, controller.loyalty(@post).user
  end

  def test_loyalty_record_defaults_to_nil
    assert_nil @controller.loyalty.record
  end

  # authorize!

  def test_authorize_bang_without_a_record_passes_nil_to_the_loyalty
    controller = PostsController.new(@user, { action: 'show', controller: 'posts' })

    assert_equal true, controller.authorize!
  end

  def test_authorize_bang_queries_the_action_name_with_a_question_mark
    controller = PostsController.new(@user, { action: 'show', controller: 'posts' })

    assert_equal true, controller.authorize!(@post)
  end

  def test_authorize_bang_uses_banken_user_for_the_loyalty
    controller = CustomUserController.new(@user, { action: 'update', controller: 'posts' })

    error = assert_raises(Banken::NotAuthorizedError) { controller.authorize!(@post) }
    assert_equal :custom_user, error.loyalty.user
  end

  def test_authorize_bang_denies_when_the_query_returns_a_falsy_value
    @controller.params[:action] = 'destroy'

    assert_raises(Banken::NotAuthorizedError) { @controller.authorize!(@post) }
  end

  def test_authorize_bang_denies_when_the_record_belongs_to_someone_else
    other_post = Post.new(Object.new, 2)

    assert_raises(Banken::NotAuthorizedError) { @controller.authorize!(other_post) }
  end

  def test_not_authorized_error_carries_controller_query_and_loyalty
    @controller.params[:action] = 'destroy'

    error = assert_raises(Banken::NotAuthorizedError) { @controller.authorize!(@post) }
    assert_equal 'posts', error.controller
    assert_equal 'destroy?', error.query
    assert_instance_of PostsLoyalty, error.loyalty
    assert_same @post, error.loyalty.record
  end

  def test_authorize_bang_marks_authorization_performed_even_when_denied
    @controller.params[:action] = 'destroy'
    assert_raises(Banken::NotAuthorizedError) { @controller.authorize!(@post) }

    assert_equal true, @controller.banken_authorization_performed?
  end

  def test_authorization_state_is_per_controller_instance
    @controller.authorize!(@post)
    other = PostsController.new(@user, { action: 'update', controller: 'posts' })

    assert_equal false, other.banken_authorization_performed?
  end

  def test_skip_authorization_marks_authorization_performed
    @controller.skip_authorization

    assert_equal true, @controller.banken_authorization_performed?
  end

  # permitted_attributes

  def test_permitted_attributes_returns_permitted_parameters
    params = ActionController::Parameters.new(controller: 'posts', action: 'update', post: { title: 'Hi', votes: 1 })
    permitted = PostsController.new(@user, params).permitted_attributes(@post)

    assert_kind_of ActionController::Parameters, permitted
    assert permitted.permitted?
  end

  def test_permitted_attributes_filters_out_attributes_the_loyalty_does_not_list
    params = ActionController::Parameters.new(controller: 'posts', action: 'update', post: { title: 'Hi', admin: true })
    permitted = PostsController.new(@user, params).permitted_attributes(@post)

    refute permitted.key?('admin')
  end

  def test_permitted_attributes_raises_parameter_missing_when_the_record_key_is_absent
    params = ActionController::Parameters.new(controller: 'posts', action: 'update')

    assert_raises(ActionController::ParameterMissing) { PostsController.new(@user, params).permitted_attributes(@post) }
  end

  def test_permitted_attributes_uses_the_demodulized_class_name_as_the_params_key
    # Current behaviour: Admin::Post reads params[:post], not params[:admin_post].
    params = ActionController::Parameters.new(controller: 'admin/posts', action: 'create', post: { title: 'Hi' })
    permitted = PostsController.new(@user, params).permitted_attributes(Admin::Post.new)

    assert_equal({ 'title' => 'Hi' }, permitted.to_h)
  end

  # verify_authorized

  def test_verify_authorized_error_is_a_banken_error
    error = assert_raises(Banken::AuthorizationNotPerformedError) { @controller.verify_authorized }

    assert_kind_of Banken::Error, error
  end
end
