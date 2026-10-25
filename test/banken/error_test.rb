require "test_helper"

class ErrorTest < Minitest::Test
  def test_all_errors_descend_from_banken_error_so_apps_can_rescue_them_together
    [Banken::NotAuthorizedError, Banken::NotDefinedError, Banken::AuthorizationNotPerformedError].each do |klass|
      assert_operator klass, :<, Banken::Error
    end
    assert_operator Banken::Error, :<, StandardError
  end

  def test_not_authorized_error_exposes_controller_query_and_loyalty
    loyalty = PostsLoyalty.new(:user, :record)
    error = Banken::NotAuthorizedError.new(controller: "posts", query: "update?", loyalty: loyalty)

    assert_equal "posts", error.controller
    assert_equal "update?", error.query
    assert_same loyalty, error.loyalty
  end

  def test_not_authorized_error_default_message_names_the_query_and_the_controller
    error = Banken::NotAuthorizedError.new(controller: "posts", query: "update?", loyalty: PostsLoyalty.new(nil, nil))

    assert_includes error.message, "update?"
    assert_includes error.message, "posts"
  end

  def test_not_authorized_error_accepts_a_custom_message_option
    error = Banken::NotAuthorizedError.new(controller: "posts", query: "update?", message: "custom")

    assert_equal "custom", error.message
    assert_equal "posts", error.controller
  end

  def test_not_authorized_error_can_be_raised_without_arguments
    error = assert_raises(Banken::NotAuthorizedError) { raise Banken::NotAuthorizedError }
    assert_nil error.query
    refute_empty error.message
  end

  def test_not_authorized_error_string_form_leaves_attributes_nil
    error = Banken::NotAuthorizedError.new("must be logged in")

    assert_nil error.controller
    assert_nil error.query
    assert_nil error.loyalty
  end

  def test_default_message_does_not_include_user_or_record_details
    user = Struct.new(:email, :password_digest).new("alice@example.com", "SECRET_HASH")
    record = Struct.new(:body) do
      def inspect; "#<Post body=SECRET_BODY>"; end
    end.new("SECRET_BODY")
    error = Banken::NotAuthorizedError.new(controller: "posts", query: "update?", loyalty: PostsLoyalty.new(user, record))

    refute_includes error.message, "SECRET_HASH"
    refute_includes error.message, "SECRET_BODY"
    refute_includes error.message, "alice@example.com"
  end

  def test_default_message_names_the_loyalty_class
    error = Banken::NotAuthorizedError.new(controller: "posts", query: "update?", loyalty: PostsLoyalty.new(nil, nil))

    assert_includes error.message, "PostsLoyalty"
  end

  def test_default_message_without_a_loyalty_still_names_query_and_controller
    error = Banken::NotAuthorizedError.new(controller: "posts", query: "update?")

    assert_includes error.message, "update?"
    assert_includes error.message, "posts"
  end
end
