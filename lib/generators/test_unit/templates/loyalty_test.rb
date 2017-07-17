require 'test_helper'

class <%= class_name %>LoyaltyTest < ActiveSupport::TestCase
  setup do
    user   = User.new
    record = nil
    @loyalty = <%= class_name %>Loyalty.new(user, record)
  end

  test "index?" do
    assert_equal false, @loyalty.index?
  end

  test "show?" do
    assert_equal false, @loyalty.show?
  end

  test "create?" do
    assert_equal false, @loyalty.create?
  end

  test "update?" do
    assert_equal false, @loyalty.update?
  end

  test "destroy?" do
    assert_equal false, @loyalty.destroy?
  end
end
