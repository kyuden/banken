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

  def test_namespaced_lookup_does_not_fall_back_to_the_top_level_loyalty
    # Only CommentsLoyalty exists. An admin controller must not silently get it.
    assert_equal CommentsLoyalty, Banken::LoyaltyFinder.new("comments").loyalty
    assert_nil Banken::LoyaltyFinder.new("admin/comments").loyalty
    assert_raises(Banken::NotDefinedError) { Banken::LoyaltyFinder.new("admin/comments").loyalty! }
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
    error = assert_raises(Banken::NotDefinedError) { Banken::LoyaltyFinder.new(nil).loyalty! }

    assert_equal "unable to find a loyalty: no controller name was given", error.message
  end

  def test_empty_controller_name_never_resolves_a_top_level_loyalty_constant
    Object.const_set(:Loyalty, Class.new(ApplicationLoyalty))

    assert_nil Banken::LoyaltyFinder.new("").loyalty
    assert_nil Banken::LoyaltyFinder.new(nil).loyalty
  ensure
    Object.send(:remove_const, :Loyalty) if Object.const_defined?(:Loyalty, false)
  end

  def test_does_not_resolve_classes_without_the_loyalty_suffix
    assert_nil Banken::LoyaltyFinder.new("post").loyalty
  end

  def test_resolution_triggers_autoload_for_lazily_defined_loyalties
    # Rails apps define loyalties through Zeitwerk autoloading, so the lookup
    # must go through constant resolution that honours Module#autoload.
    Object.autoload :LazyPostsLoyalty, File.expand_path("../fixtures/lazy_posts_loyalty.rb", __dir__)

    loyalty_class = Banken::LoyaltyFinder.new("lazy_posts").loyalty!

    assert_equal "LazyPostsLoyalty", loyalty_class.name
    assert_nil Object.autoload?(:LazyPostsLoyalty), "constant should have been loaded by the lookup"
  end

  def test_errors_inside_an_autoloaded_loyalty_file_propagate
    # A NoMethodError raised while the loyalty file is being loaded is a bug in
    # the application, not a missing loyalty. It must surface as itself.
    Object.autoload :BuggyPostsLoyalty, File.expand_path("../fixtures/buggy_posts_loyalty.rb", __dir__)

    error = assert_raises(NoMethodError) { Banken::LoyaltyFinder.new("buggy_posts").loyalty! }
    assert_includes error.message, "permit_everything_for"
  ensure
    Object.send(:remove_const, :BuggyPostsLoyalty) if Object.const_defined?(:BuggyPostsLoyalty, false)
  end

  def test_missing_parent_namespace_is_treated_as_missing
    assert_nil Banken::LoyaltyFinder.new("nonexistent_ns/posts").loyalty
    assert_raises(Banken::NotDefinedError) { Banken::LoyaltyFinder.new("nonexistent_ns/posts").loyalty! }
  end

  def test_not_defined_error_message_names_the_expected_file
    error = assert_raises(Banken::NotDefinedError) { Banken::LoyaltyFinder.new("admin/articles").loyalty! }

    assert_includes error.message, "app/loyalties/admin/articles_loyalty.rb"
  end

  def test_suffix_constant_is_part_of_the_public_contract
    assert_equal "Loyalty", Banken::LoyaltyFinder::SUFFIX
  end
end
