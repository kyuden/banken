require "test_helper"
require "rails"
require "banken/railtie"

class RailtieTest < Minitest::Test
  FakeApp = Struct.new(:deprecators)

  def test_railtie_is_a_rails_railtie
    assert_operator Banken::Railtie, :<, Rails::Railtie
  end

  def test_railtie_registers_the_deprecator_with_the_application
    initializer = Banken::Railtie.initializers.find { |i| i.name == "banken.deprecator" }
    refute_nil initializer, "expected a banken.deprecator initializer"

    app = FakeApp.new({})
    initializer.block.call(app)

    assert_same Banken.deprecator, app.deprecators[:banken]
  end
end
