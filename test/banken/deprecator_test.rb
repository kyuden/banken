require "test_helper"

class DeprecatorTest < Minitest::Test
  def test_banken_exposes_its_own_deprecator
    assert_kind_of ActiveSupport::Deprecation, Banken.deprecator
  end

  def test_deprecator_is_named_after_the_gem_and_targets_2_0
    assert_equal "Banken", Banken.deprecator.gem_name
    assert_equal "2.0", Banken.deprecator.deprecation_horizon
  end

  def test_deprecator_is_a_single_shared_instance
    assert_same Banken.deprecator, Banken.deprecator
  end

  def test_deprecated_method_warns_through_the_banken_deprecator
    controller = PostsController.new(Object.new, { action: 'update', controller: 'posts' })
    messages = []
    previous = Banken.deprecator.behavior
    Banken.deprecator.behavior = ->(message, *) { messages << message }

    controller.banken_loyalty_authorized?

    assert_equal 1, messages.size
    assert_match(/banken_loyalty_authorized\? is deprecated, use banken_authorization_performed\? instead/, messages.first)
  ensure
    Banken.deprecator.behavior = previous if previous
  end

  def test_silencing_the_banken_deprecator_silences_the_deprecated_method
    controller = PostsController.new(Object.new, { action: 'update', controller: 'posts' })

    assert_silent do
      Banken.deprecator.silence { controller.banken_loyalty_authorized? }
    end
  end
end
