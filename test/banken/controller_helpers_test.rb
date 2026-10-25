require "test_helper"

# Unit tests for the controller mixin using the fake PostsController.
# These cover behaviour the original suite left implicit.
class ControllerHelpersTest < Minitest::Test
  class CustomUserController < PostsController
    def banken_user
      :custom_user
    end
  end

  # Looks like a real Rails controller: has action_name and controller_path
  # that deliberately disagree with params.
  class RailsLikeController < PostsController
    def action_name
      'show'
    end

    def controller_path
      'admin/posts'
    end
  end

  def setup
    @user = Object.new
    @post = Post.new(@user, 1)
    @controller = PostsController.new(@user, { action: 'update', controller: 'posts' })
  end

  # loyalty resolution

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

  def test_inference_prefers_action_name_and_controller_path_over_params
    # Inverted from the 1.0.x behaviour (params first) in 1.1.0: Rails sets
    # action_name and controller_path on every controller, and they are also
    # available where params[:controller] is not (direct dispatch, Renderer).
    controller = RailsLikeController.new(@user, { action: 'destroy', controller: 'posts' })

    error = assert_raises(Banken::NotAuthorizedError) { controller.authorize!(@post) }
    assert_instance_of Admin::PostsLoyalty, error.loyalty
    assert_equal 'show?', error.query
    assert_equal 'admin/posts', error.controller
  end

  def test_inference_falls_back_to_params_when_the_controller_has_no_action_name
    refute_respond_to @controller, :action_name
    @controller.params[:action] = 'destroy'

    error = assert_raises(Banken::NotAuthorizedError) { @controller.authorize!(@post) }
    assert_equal 'destroy?', error.query
    assert_equal 'posts', error.controller
  end

  def test_inference_falls_back_to_params_when_action_name_is_nil
    # ActionController::Metal#action_name is nil until #process runs.
    unprocessed = Class.new(PostsController) do
      def action_name; nil; end
      def controller_path; nil; end
    end
    controller = unprocessed.new(@user, { action: 'destroy', controller: 'posts' })

    error = assert_raises(Banken::NotAuthorizedError) { controller.authorize!(@post) }
    assert_equal 'destroy?', error.query
    assert_equal 'posts', error.controller
  end

  def test_loyalty_class_is_resolved_fresh_for_each_controller_instance
    # Guards against a process-wide cache: after code reloading a new request
    # must see the redefined class.
    Object.const_set(:ReloadablesLoyalty, Class.new(ApplicationLoyalty))
    first = PostsController.new(@user, { action: 'show', controller: 'reloadables' }).loyalty.class

    Object.send(:remove_const, :ReloadablesLoyalty)
    Object.const_set(:ReloadablesLoyalty, Class.new(ApplicationLoyalty))
    second = PostsController.new(@user, { action: 'show', controller: 'reloadables' }).loyalty.class

    refute_same first, second
    assert_same ReloadablesLoyalty, second
  ensure
    Object.send(:remove_const, :ReloadablesLoyalty) if Object.const_defined?(:ReloadablesLoyalty, false)
  end

  def test_authorize_bang_raises_a_banken_error_when_no_action_name_can_be_inferred
    # ActionController::Renderer: controller_path is set, action_name is nil, params are empty.
    renderer_like = Class.new(PostsController) do
      def action_name; nil; end
      def controller_path; "posts"; end
    end
    controller = renderer_like.new(@user, {})

    assert_instance_of PostsLoyalty, controller.loyalty(@post)
    error = assert_raises(Banken::Error) { controller.authorize!(@post) }
    assert_includes error.message, "action name"
  end

  # loyalty class memoization (per controller instance; instances are never cached)

  def test_loyalty_class_is_resolved_once_per_controller_instance
    assert_equal 1, finder_instantiations { @controller.loyalty(@post); @controller.loyalty(@post2); @controller.loyalty }
  end

  def test_loyalty_class_memo_is_keyed_by_controller_name
    assert_equal 2, finder_instantiations { @controller.loyalty(@post, :posts); @controller.loyalty(@post, "admin/posts"); @controller.loyalty(@post, :posts) }
    assert_instance_of Admin::PostsLoyalty, @controller.loyalty(@post, "admin/posts")
  end

  def test_loyalty_class_memo_treats_symbol_and_string_names_as_the_same_key
    assert_equal 1, finder_instantiations { @controller.loyalty(@post, :posts); @controller.loyalty(@post, "posts"); @controller.loyalty(@post) }
  end

  def test_failed_lookup_is_not_memoized
    controller = PostsController.new(@user, { action: "show", controller: "late_defined" })
    assert_raises(Banken::NotDefinedError) { controller.loyalty }

    Object.const_set(:LateDefinedLoyalty, Class.new(ApplicationLoyalty))
    assert_instance_of LateDefinedLoyalty, controller.loyalty
  ensure
    Object.send(:remove_const, :LateDefinedLoyalty) if Object.const_defined?(:LateDefinedLoyalty, false)
  end

  def test_loyalty_instances_follow_banken_user_changes_within_a_request
    first = @controller.loyalty(@post)
    @controller.current_user = :switched
    second = @controller.loyalty(@post)

    assert_equal @user, first.user
    assert_equal :switched, second.user
    refute_same first, second
  end

  def test_module_level_loyalty_bang_is_not_memoized
    assert_equal 2, finder_instantiations { Banken.loyalty!(:posts, @user, @post); Banken.loyalty!(:posts, @user, @post) }
  end

  # authorize!

  def test_authorize_bang_without_a_record_passes_nil_to_the_loyalty
    controller = PostsController.new(@user, { action: 'destroy', controller: 'posts' })

    error = assert_raises(Banken::NotAuthorizedError) { controller.authorize! }
    assert_nil error.loyalty.record
  end

  def test_authorize_bang_uses_banken_user_for_the_loyalty
    controller = CustomUserController.new(@user, { action: 'update', controller: 'posts' })

    error = assert_raises(Banken::NotAuthorizedError) { controller.authorize!(@post) }
    assert_equal :custom_user, error.loyalty.user
  end

  def test_authorize_bang_denies_when_the_query_returns_nil
    @controller.params[:action] = 'archive'

    assert_raises(Banken::NotAuthorizedError) { @controller.authorize!(@post) }
  end

  def test_authorize_bang_allows_when_the_query_returns_a_truthy_non_boolean
    @controller.params[:action] = 'publish'

    assert_equal true, @controller.authorize!(@post)
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

  def test_permitted_attributes_accepts_a_class_record
    # README: "If you do not have an object ... you can pass the class."
    params = ActionController::Parameters.new(controller: "posts", action: "create", post: { title: "Hi", votes: 1, admin: true })
    permitted = PostsController.new(@user, params).permitted_attributes(Post)

    assert_equal({ "votes" => 1 }, permitted.to_h)
  end

  def test_permitted_attributes_never_reads_a_params_key_named_class
    params = ActionController::Parameters.new(controller: "posts", action: "create", class: { votes: 99 }, post: { votes: 1 })
    permitted = PostsController.new(@user, params).permitted_attributes(Post)

    assert_equal({ "votes" => 1 }, permitted.to_h)
  end

  def test_banken_param_key_can_be_overridden_to_use_model_name
    controller_class = Class.new(PostsController) do
      private

        def banken_param_key(record)
          record.respond_to?(:model_name) ? record.model_name.param_key : super
        end
    end
    params = ActionController::Parameters.new(controller: "admin/posts", action: "create", admin_post: { title: "Hi" }, post: { title: "wrong" })
    permitted = controller_class.new(@user, params).permitted_attributes(Admin::Post.new)

    assert_equal({ "title" => "Hi" }, permitted.to_h)
  end

  def test_banken_param_key_override_can_fall_back_to_the_default_with_super
    controller_class = Class.new(PostsController) do
      private

        def banken_param_key(record)
          record.respond_to?(:model_name) ? record.model_name.param_key : super
        end
    end
    params = ActionController::Parameters.new(controller: "posts", action: "update", post: { votes: 3 })
    permitted = controller_class.new(@user, params).permitted_attributes(@post)

    assert_equal({ "votes" => 3 }, permitted.to_h)
  end

  def test_permitted_attributes_rejects_an_anonymous_class_record
    params = ActionController::Parameters.new(controller: "posts", action: "create")

    assert_raises(ArgumentError) { PostsController.new(@user, params).permitted_attributes(Class.new) }
  end

  def test_banken_params_for_can_be_overridden
    controller_class = Class.new(PostsController) do
      private

        def banken_params_for(record)
          params.fetch(:payload)
        end
    end
    params = ActionController::Parameters.new(controller: "posts", action: "update", payload: { title: "Hi", votes: 2, admin: true })
    permitted = controller_class.new(@user, params).permitted_attributes(@post)

    assert_equal({ "title" => "Hi", "votes" => 2 }, permitted.to_h)
  end

  # verify_authorized

  def test_verify_authorized_error_is_a_banken_error
    error = assert_raises(Banken::AuthorizationNotPerformedError) { @controller.verify_authorized }

    assert_kind_of Banken::Error, error
  end

  private

    def finder_instantiations
      count = 0
      original = Banken::LoyaltyFinder.method(:new)
      Banken::LoyaltyFinder.stub(:new, ->(name) { count += 1; original.call(name) }) { yield }
      count
    end
end
