require "test_helper"

class LoyaltyFinderTest < Minitest::Test
  def test_resolves_a_plain_controller_name
    assert_equal PostsLoyalty, Banken::LoyaltyFinder.new("posts").loyalty
  end

  def test_resolves_a_symbol_controller_name
    assert_equal PostsLoyalty, Banken::LoyaltyFinder.new(:posts).loyalty
  end

  def test_resolves_a_namespaced_controller_path
    assert_equal Admin::PostsLoyalty, Banken::LoyaltyFinder.new("admin/posts").loyalty
  end

  def test_stores_the_controller_name_as_a_string
    assert_equal "admin/posts", Banken::LoyaltyFinder.new(:"admin/posts").controller_name
  end

  def test_loyalty_returns_nil_when_the_class_is_missing
    assert_nil Banken::LoyaltyFinder.new("articles").loyalty
  end

  def test_loyalty_bang_raises_not_defined_error_naming_both_the_class_and_the_controller
    error = assert_raises(Banken::NotDefinedError) { Banken::LoyaltyFinder.new("articles").loyalty! }
    assert_includes error.message, "ArticlesLoyalty"
    assert_includes error.message, "articles"
  end

  def test_loyalty_bang_raises_not_defined_error_for_a_missing_namespaced_class
    error = assert_raises(Banken::NotDefinedError) { Banken::LoyaltyFinder.new("admin/articles").loyalty! }
    assert_includes error.message, "Admin::ArticlesLoyalty"
  end

  def test_nil_controller_name_is_treated_as_missing_rather_than_crashing
    assert_raises(Banken::NotDefinedError) { Banken::LoyaltyFinder.new(nil).loyalty! }
  end

  def test_does_not_resolve_classes_without_the_loyalty_suffix
    assert_nil Banken::LoyaltyFinder.new("post").loyalty
  end

  def test_suffix_constant_is_part_of_the_public_contract
    assert_equal "Loyalty", Banken::LoyaltyFinder::SUFFIX
  end
end
