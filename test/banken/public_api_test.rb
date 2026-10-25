require "test_helper"

# Pins the surface Banken adds to a controller. Any change here is an API
# change for every application that includes Banken and must be deliberate.
class PublicApiTest < Minitest::Test
  EXPECTED_PUBLIC_METHODS = %w[
    authorize!
    banken_authorization_performed?
    banken_loyalty_authorized?
    banken_user
    loyalty
    permitted_attributes
    skip_authorization
    verify_authorized
  ].freeze

  def test_public_instance_methods_added_to_the_controller
    assert_equal EXPECTED_PUBLIC_METHODS, Banken.public_instance_methods(false).map(&:to_s).sort
  end

  def test_inference_hooks_stay_private
    # Not an exhaustive list: private helpers may be added freely. These three
    # must simply never become public actions.
    %i[banken_action_name banken_controller_name banken_query_name].each do |name|
      assert_includes Banken.private_instance_methods(false), name
    end
  end

  def test_module_level_loyalty_bang_is_available_outside_controllers
    assert_respond_to Banken, :loyalty!
  end

  def test_version_is_a_gem_version_string
    assert_match(/\A\d+\.\d+\.\d+\z/, Banken::VERSION)
  end

  def test_registers_loyalty_and_banken_user_as_view_helpers_when_supported
    registered = []
    host = Class.new do
      define_singleton_method(:helper_method) { |*names| registered.concat(names) }
    end

    host.include Banken

    assert_equal [:loyalty, :banken_user], registered
  end

  def test_can_be_included_into_a_class_without_helper_method_support
    host = Class.new { include Banken }

    assert_includes host.ancestors, Banken
  end
end
