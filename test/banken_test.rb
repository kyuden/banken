require "test_helper"

class BankenTest < Minitest::Test
  def setup
    @user = Object.new
    @post = Post.new(@user, 1)
    @post2 = Post.new(@user, 2)
    @article = Article.new
    @posts_controller = PostsController.new(@user, { :action => 'update', :controller => 'posts' })
  end

  # Banken.loyalty!

  def test_loyalty_bang_returns_an_instantiated_loyalty_given_a_controller_name
    loyalty = Banken.loyalty!('posts', @user, @post)
    assert_equal @user, loyalty.user
    assert_equal @post, loyalty.record
    assert_equal 'PostsLoyalty', loyalty.class.name
  end

  def test_loyalty_bang_returns_an_instantiated_loyalty_given_a_controller_name_of_symbol
    loyalty = Banken.loyalty!(:posts, @user, @post)
    assert_equal @user, loyalty.user
    assert_equal @post, loyalty.record
    assert_equal 'PostsLoyalty', loyalty.class.name
  end

  def test_loyalty_bang_returns_an_instantiated_loyalty_given_record_is_nil
    loyalty = Banken.loyalty!(:posts, @user)
    assert_equal @user, loyalty.user
    assert_nil loyalty.record
    assert_equal 'PostsLoyalty', loyalty.class.name
  end

  def test_loyalty_bang_raises_if_the_given_loyalty_cannot_be_found
    assert_raises(Banken::NotDefinedError) { Banken.loyalty!('articles', @user, @article) }
  end

  # #verify_authorized

  def test_verify_authorized_does_nothing_when_authorized
    @posts_controller.authorize!(@post)
    assert_nil @posts_controller.verify_authorized
  end

  def test_verify_authorized_raises_when_not_authorized
    assert_raises(Banken::AuthorizationNotPerformedError) { @posts_controller.verify_authorized }
  end

  # #banken_loyalty_authorized? (deprecated)

  def test_banken_loyalty_authorized_is_true_when_authorized
    @posts_controller.authorize!(@post)
    assert_equal true, @posts_controller.banken_loyalty_authorized?
  end

  def test_banken_loyalty_authorized_is_false_when_not_authorized
    assert_equal false, @posts_controller.banken_loyalty_authorized?
  end

  def test_banken_loyalty_authorized_outputs_deprecation_warning
    assert_output(nil, /^DEPRECATION WARNING: banken_loyalty_authorized\? is deprecated, use banken_authorization_performed\? instead\./) do
      @posts_controller.banken_loyalty_authorized?
    end
  end

  # #banken_authorization_performed?

  def test_banken_authorization_performed_is_true_when_authorized
    @posts_controller.authorize!(@post)
    assert_equal true, @posts_controller.banken_authorization_performed?
  end

  def test_banken_authorization_performed_is_false_when_not_authorized
    assert_equal false, @posts_controller.banken_authorization_performed?
  end

  # #skip_authorization

  def test_skip_authorization_disables_authorization_verification
    @posts_controller.skip_authorization
    assert_nil @posts_controller.verify_authorized
  end

  # #authorize!

  def test_authorize_bang_infers_the_loyalty_name_and_authorizes_based_on_it
    assert_equal true, @posts_controller.authorize!(@post)
  end

  def test_authorize_bang_raises_not_authorized_error_when_action_returns_false
    @posts_controller.params[:action] = 'destroy'
    assert_raises(Banken::NotAuthorizedError) { @posts_controller.authorize!(@post) }
  end

  def test_authorize_bang_raises_not_defined_error_when_loyalty_is_missing
    @posts_controller.params[:controller] = 'articles'
    assert_raises(Banken::NotDefinedError) { @posts_controller.authorize!(@article) }
  end

  def test_authorize_bang_raises_no_method_error_when_action_is_missing_in_loyalty
    @posts_controller.params[:action] = 'update_all'
    assert_raises(NoMethodError) { @posts_controller.authorize!(@post) }
  end

  # #banken_user

  def test_banken_user_returns_the_same_thing_as_current_user
    assert_equal @posts_controller.current_user, @posts_controller.banken_user
  end

  # #loyalty

  def test_loyalty_returns_an_instantiated_loyalty
    loyalty = @posts_controller.loyalty(@post, 'posts')
    assert_equal @user, loyalty.user
    assert_equal @post, loyalty.record
  end

  def test_loyalty_returns_a_different_loyalty_for_each_record
    loyalty = @posts_controller.loyalty(@post, 'posts')
    loyalty2 = @posts_controller.loyalty(@post2, 'posts')
    refute_same loyalty, loyalty2
  end

  def test_loyalty_raises_if_the_given_loyalty_cannot_be_found
    assert_raises(Banken::NotDefinedError) { @posts_controller.loyalty(@article, 'articles') }
  end

  # #permitted_attributes

  def test_permitted_attributes_checks_loyalty_for_permitted_attributes
    params = ActionController::Parameters.new({ controller: 'posts', action: 'update', post: { title: 'Hello', votes: 5, admin: true } })

    assert_equal({ 'title' => 'Hello', 'votes' => 5 }, PostsController.new(@user, params).permitted_attributes(@post).to_h)
    assert_equal({ 'votes' => 5 }, PostsController.new(Object.new, params).permitted_attributes(@post).to_h)
  end

  # Banken::NotAuthorizedError

  def test_not_authorized_error_can_be_initialized_with_a_string_as_message
    error = Banken::NotAuthorizedError.new("must be logged in")
    assert_equal "must be logged in", error.message
  end
end
