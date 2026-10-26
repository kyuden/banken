require "test_helper"

# `include Banken::Authorization` is the recommended way to get the controller
# helpers. `include Banken` must keep working, but it drags the whole Banken
# namespace into the controller's constant lookup (Pundit had the same problem,
# fixed with Pundit::Authorization in 2.2.0).
class AuthorizationTest < Minitest::Test
  class ApplicationError < StandardError; end

  # Top-level application constants, like an app's own `Error` class. Constant
  # lookup inside a controller checks the controller's ancestors (including
  # mixed-in modules) before Object, which is how `include Banken` shadows them.
  def setup
    Object.const_set(:Error, ApplicationError)
    Object.const_set(:VERSION, "app-9.9")
  end

  def teardown
    Object.send(:remove_const, :Error)
    Object.send(:remove_const, :VERSION)
  end

  # class_eval with a string so constant lookup happens inside the host class,
  # as it does for methods written in a controller file.
  def host_including(mod)
    host = Class.new { include mod }
    host.class_eval("def self.resolved; [Error, VERSION]; end")
    host
  end

  def test_including_authorization_does_not_shadow_application_constants
    assert_equal [ApplicationError, "app-9.9"], host_including(Banken::Authorization).resolved
  end

  def test_including_banken_itself_still_shadows_application_constants
    # Pinned so the compatibility behaviour is a known, documented quantity.
    assert_equal [Banken::Error, Banken::VERSION], host_including(Banken).resolved
  end

  def test_including_banken_provides_the_same_helpers_as_authorization
    host = host_including(Banken)
    helpers = Banken::Authorization.public_instance_methods(false).sort
    assert_equal helpers, (host.public_instance_methods - Object.public_instance_methods).sort
    assert_includes host.ancestors, Banken::Authorization
  end

  def test_banken_module_itself_defines_no_instance_methods
    assert_empty Banken.public_instance_methods(false)
    assert_empty Banken.private_instance_methods(false)
  end

  def test_both_include_styles_register_the_view_helpers_once
    [Banken, Banken::Authorization].each do |mod|
      registered = []
      host = Class.new { define_singleton_method(:helper_method) { |*names| registered.concat(names) } }
      host.include mod
      assert_equal [:loyalty, :banken_user], registered, "via #{mod}"
    end
  end

  def test_authorization_works_in_a_controller_that_includes_it_directly
    controller_class = Class.new do
      include Banken::Authorization
      attr_accessor :current_user, :params
      def initialize(user, params); @current_user = user; @params = params; end
    end
    user = Object.new
    controller = controller_class.new(user, { action: "show", controller: "posts" })

    assert_equal true, controller.authorize!(Post.new(user, 1))
    assert_instance_of PostsLoyalty, controller.loyalty
    assert_equal true, controller.banken_authorization_performed?
  end
end
