# frozen_string_literal: true

require "active_support/concern"
require "active_support/core_ext/string/inflections"
require "active_support/core_ext/object/blank"
require "banken/version"
require "banken/error"
require "banken/loyalty_finder"
require "banken/deprecator"
require "banken/railtie" if defined?(::Rails::Railtie)

module Banken
  extend ActiveSupport::Concern

  included do
    if respond_to?(:helper_method)
      helper_method :loyalty
      helper_method :banken_user
    end
  end

  class << self
    def loyalty!(controller_name, user, record=nil)
      LoyaltyFinder.new(controller_name).loyalty!.new(user, record)
    end
  end

  def authorize!(record=nil)
    @_banken_authorization_performed = true

    loyalty = loyalty(record)
    unless loyalty.public_send(banken_query_name)
      raise NotAuthorizedError.new(controller: banken_controller_name, query: banken_query_name, loyalty: loyalty)
    end

    true
  end

  def permitted_attributes(record)
    banken_params_for(record).permit(loyalty(record).permitted_attributes)
  end

  def loyalty(record=nil, controller_name=nil)
    controller_name = banken_controller_name unless controller_name
    banken_loyalty_class(controller_name).new(banken_user, record)
  end

  def banken_user
    current_user
  end

  def skip_authorization
    @_banken_authorization_performed = true
  end

  def verify_authorized
    raise AuthorizationNotPerformedError unless banken_authorization_performed?
  end

  def banken_authorization_performed?
    !!@_banken_authorization_performed
  end

  # @deprecated Use banken_authorization_performed? instead.
  def banken_loyalty_authorized?
    Banken.deprecator.warn('banken_loyalty_authorized? is deprecated, use banken_authorization_performed? instead.')
    banken_authorization_performed?
  end

  private

    # Rails sets action_name and controller_path on every controller and, unlike
    # params[:controller] / params[:action], they cannot be supplied by the
    # request: for routes that target an endpoint directly
    # (`get "/x" => PostsController.action(:destroy)`, `mount`) the path
    # parameters carry no controller or action, so params would come from the
    # query string. They are also available where params are not, such as a
    # controller dispatched with Controller.action(...).call(env) and views
    # rendered through ActionController::Renderer (controller_path only; there
    # is no action there). params remain the fallback for non-Rails hosts that
    # only provide params, for action_name being nil before #process runs, and
    # for anonymous controllers whose controller_path is nil.
    def banken_action_name
      (respond_to?(:action_name) && action_name.presence) || params[:action]
    end

    def banken_controller_name
      (respond_to?(:controller_path) && controller_path.presence) || params[:controller]
    end

    # Resolving a loyalty class means camelizing and constantizing the controller
    # name (a few microseconds, more for namespaced names); a view may do that
    # dozens of times per request. Memoize the class per controller instance (i.e. per request), so
    # code reloading in development still sees new classes on the next request.
    # Only the class is memoized, never the instance: a loyalty is built fresh
    # for every record and for the current banken_user.
    def banken_loyalty_class(controller_name)
      @_banken_loyalty_classes ||= {}
      @_banken_loyalty_classes[controller_name.to_s] ||= LoyaltyFinder.new(controller_name).loyalty!
    end

    # The parameters that hold the attributes of `record`, before filtering.
    # Override (keep it private) to read them from somewhere else.
    def banken_params_for(record)
      params.require(banken_param_key(record))
    end

    # The params key for `record`, which may be an instance or a class:
    # Post / Post.new -> "post", Admin::Post -> "post". Override (keep it
    # private) to use e.g. `record.model_name.param_key` ("admin_post").
    def banken_param_key(record)
      klass = record.is_a?(Class) ? record : record.class
      name  = klass.name || raise(ArgumentError, "cannot infer a params key for an anonymous class")
      name.demodulize.underscore
    end

    def banken_query_name
      action = banken_action_name
      if action.blank?
        raise Error, "unable to infer the query: no action name is available (authorize! must run inside a controller action)"
      end
      "#{action}?"
    end
end
