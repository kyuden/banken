require "test_helper"
require "rack/mock"

# Exercises Banken inside real ActionController classes dispatched through an
# ActionDispatch route set, without booting a Rails application. This is where
# the controller/action inference, helper registration, after_action
# verification and strong parameters integration actually happen.
module Integration
  class ApplicationLoyalty
    attr_reader :user, :record

    def initialize(user, record)
      @user = user
      @record = record
    end
  end

  class PostsLoyalty < ApplicationLoyalty
    def index?;   true; end
    def show?;    true; end
    def update?;  record.user == user; end
    def edit?;    update?; end
    def destroy?; false; end
    def create?;  true; end

    def permitted_attributes
      user == :admin ? [:title, :body] : [:title]
    end
  end

  class RawLoyalty < PostsLoyalty; end
  class CustomUsersLoyalty < ApplicationLoyalty
    def show?; user == :from_banken_user; end
  end

  module Admin
    class PostsLoyalty < ApplicationLoyalty
      def index?; user == :admin; end
    end
  end

  module Api
    class PostsLoyalty < ApplicationLoyalty
      def index?; true; end
    end
  end

  class StrictLoyalty < ApplicationLoyalty
    def initialize(user, record)
      raise Banken::NotAuthorizedError, "must be logged in" unless user
      super
    end

    def show?; true; end
  end

  class ApplicationController < ActionController::Base
    include Banken

    after_action :verify_authorized
    rescue_from Banken::NotAuthorizedError, with: :user_not_authorized

    def current_user
      request.env["banken.user"]
    end

    private
      def user_not_authorized(error)
        render plain: "denied controller=#{error.controller} query=#{error.query} loyalty=#{error.loyalty.class}", status: :forbidden
      end

      def find_post
        owner = request.env["banken.owner"] ? current_user : :someone_else
        Post.new(owner, params[:id])
      end
  end

  class PostsController < ApplicationController
    before_action :require_login, only: [:edit, :unverified_after_filter]

    def index
      authorize!
      render plain: "index ok"
    end

    def unverified_after_filter
      render plain: "forgot to authorize after a filter"
    end

    def show
      authorize!(find_post)
      render plain: "show ok"
    end

    def edit
      authorize!(find_post)
      render plain: "edit ok"
    end

    def update
      authorize!(find_post)
      render plain: "update ok"
    end

    def destroy
      authorize!(find_post)
      render plain: "destroy ok"
    end

    def create
      authorize!
      render plain: permitted_attributes(Post.new(current_user, nil)).to_h.to_a.sort.inspect
    end

    def unverified
      render plain: "forgot to authorize"
    end

    def inline_view
      skip_authorization
      @post = find_post
      render inline: "update:<%= loyalty(@post).update? %> user:<%= banken_user %> admin:<%= loyalty(@post, 'integration/admin/posts').index? %>"
    end

    def show_names
      skip_authorization
      render plain: "controller=#{send(:banken_controller_name)} action=#{send(:banken_action_name)}"
    end

    private
      def require_login
        redirect_to "/login" unless current_user == :admin
      end
  end

  class RawController < ApplicationController
    rescue_from Banken::NotAuthorizedError do |error|
      raise error
    end

    def destroy
      authorize!(find_post)
      render plain: "never"
    end
  end

  class DashboardsController < ApplicationController
    def show
      skip_authorization
      render plain: "dashboard"
    end
  end

  class CustomUsersController < ApplicationController
    def show
      authorize!
      render plain: "custom ok"
    end

    def banken_user
      :from_banken_user
    end
  end

  class StrictController < ApplicationController
    def show
      authorize!
      render plain: "strict ok"
    end
  end

  module Admin
    class PostsController < ApplicationController
      def index
        authorize!
        render plain: "admin index via #{loyalty.class}"
      end
    end
  end

  module Api
    class PostsController < ActionController::API
      include Banken

      after_action :verify_authorized

      def current_user
        request.env["banken.user"]
      end

      def index
        authorize!
        render plain: "api ok"
      end
    end
  end

  ROUTES = ActionDispatch::Routing::RouteSet.new
  ROUTES.draw do
    get    "/posts"              => "integration/posts#index"
    post   "/posts"              => "integration/posts#create"
    get    "/posts/unverified"   => "integration/posts#unverified"
    get    "/posts/unverified_after_filter" => "integration/posts#unverified_after_filter"
    get    "/posts/inline_view"  => "integration/posts#inline_view"
    get    "/posts/show_names"   => "integration/posts#show_names"
    get    "/posts/:id"          => "integration/posts#show"
    get    "/posts/:id/edit"     => "integration/posts#edit"
    patch  "/posts/:id"          => "integration/posts#update"
    delete "/posts/:id"          => "integration/posts#destroy"
    delete "/raw/:id"            => "integration/raw#destroy"
    get    "/dashboard"          => "integration/dashboards#show"
    get    "/custom_user"        => "integration/custom_users#show"
    get    "/strict"             => "integration/strict#show"
    get    "/admin/posts"        => "integration/admin/posts#index"
    get    "/api/posts"          => "integration/api/posts#index"
  end
end

class RailsControllerTest < Minitest::Test
  def request(method, path, user: :alice, owner: false, params: nil)
    env = { "banken.user" => user, "banken.owner" => owner }
    env[:params] = params if params
    Rack::MockRequest.new(Integration::ROUTES).request(method.to_s.upcase, path, env)
  end

  # inference of controller and action

  def test_authorize_bang_infers_loyalty_from_controller_path_and_query_from_action_name
    response = request(:patch, "/posts/1", owner: true)

    assert_equal 200, response.status
    assert_equal "update ok", response.body
  end

  def test_denied_request_is_handled_by_rescue_from_with_full_error_details
    response = request(:delete, "/posts/1")

    assert_equal 403, response.status
    assert_equal "denied controller=integration/posts query=destroy? loyalty=Integration::PostsLoyalty", response.body
  end

  def test_denied_when_the_record_belongs_to_another_user
    response = request(:patch, "/posts/1", owner: false)

    assert_equal 403, response.status
  end

  def test_not_authorized_error_propagates_when_not_rescued
    assert_raises(Banken::NotAuthorizedError) { request(:delete, "/raw/1") }
  end

  def test_controller_and_action_come_from_routing_not_from_the_query_string
    response = request(:get, "/posts/show_names?controller=integration/admin/posts&action=destroy")

    assert_equal "controller=integration/posts action=show_names", response.body
  end

  def test_controller_and_action_cannot_be_overridden_through_the_request_body
    response = request(:post, "/posts", params: { "controller" => "integration/raw", "action" => "destroy", "post" => { "title" => "t" } })

    assert_equal 200, response.status
    assert_equal [["title", "t"]].inspect, response.body
  end

  def test_namespaced_controllers_resolve_namespaced_loyalties
    response = request(:get, "/admin/posts", user: :admin)

    assert_equal "admin index via Integration::Admin::PostsLoyalty", response.body
  end

  def test_namespaced_controllers_are_denied_through_their_own_loyalty
    response = request(:get, "/admin/posts", user: :alice)

    assert_equal 403, response.status
    assert_includes response.body, "controller=integration/admin/posts"
  end

  def test_authorize_bang_without_a_record_works_for_collection_actions
    response = request(:get, "/posts")

    assert_equal "index ok", response.body
  end

  # verify_authorized as after_action

  def test_verify_authorized_raises_when_the_action_forgot_to_authorize
    assert_raises(Banken::AuthorizationNotPerformedError) { request(:get, "/posts/unverified") }
  end

  def test_skip_authorization_satisfies_verify_authorized
    response = request(:get, "/dashboard")

    assert_equal "dashboard", response.body
  end

  def test_verify_authorized_does_not_run_when_a_before_action_halts_the_chain
    response = request(:get, "/posts/1/edit", user: :guest)

    assert_equal 302, response.status
    assert_match %r{/login\z}, response.headers["Location"]
  end

  def test_verify_authorized_runs_after_a_before_action_that_does_not_halt
    assert_raises(Banken::AuthorizationNotPerformedError) { request(:get, "/posts/unverified_after_filter", user: :admin) }
  end

  def test_before_action_halt_also_skips_verification_of_an_unauthorized_action
    response = request(:get, "/posts/unverified_after_filter", user: :guest)

    assert_equal 302, response.status
  end

  # banken_user

  def test_banken_user_override_is_used_instead_of_current_user
    response = request(:get, "/custom_user", user: :ignored)

    assert_equal "custom ok", response.body
  end

  def test_loyalty_constructor_may_raise_not_authorized_error_for_anonymous_users
    assert_equal 403, request(:get, "/strict", user: nil).status
    assert_equal "strict ok", request(:get, "/strict", user: :alice).body
  end

  # view helpers

  def test_loyalty_and_banken_user_are_available_in_views
    response = request(:get, "/posts/inline_view", user: :admin, owner: true)

    assert_equal "update:true user:admin admin:true", response.body
  end

  def test_view_helper_reflects_denials
    response = request(:get, "/posts/inline_view", user: :alice, owner: false)

    assert_equal "update:false user:alice admin:false", response.body
  end

  # strong parameters

  def test_permitted_attributes_filters_real_request_params_through_the_loyalty
    response = request(:post, "/posts", user: :alice, params: { "post" => { "title" => "t", "body" => "b", "admin" => "1" } })

    assert_equal [["title", "t"]].inspect, response.body
  end

  def test_permitted_attributes_depends_on_the_user
    response = request(:post, "/posts", user: :admin, params: { "post" => { "title" => "t", "body" => "b", "admin" => "1" } })

    assert_equal [["body", "b"], ["title", "t"]].inspect, response.body
  end

  def test_permitted_attributes_raises_parameter_missing_for_absent_key
    assert_raises(ActionController::ParameterMissing) { request(:post, "/posts", params: { "other" => "x" }) }
  end

  # ActionController::API

  def test_works_inside_action_controller_api_which_has_no_helper_method
    response = request(:get, "/api/posts")

    assert_equal "api ok", response.body
  end
end
