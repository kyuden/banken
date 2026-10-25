require "active_support/concern"
require "active_support/core_ext/string/inflections"
require "active_support/core_ext/object/blank"
require "active_support/core_ext/module/introspection"
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

    if respond_to?(:hide_action)
      hide_action :permitted_attributes
      hide_action :loyalty
      hide_action :banken_user
      hide_action :skip_authorization
      hide_action :verify_authorized
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
    name = record.class.to_s.demodulize.underscore
    params.require(name).permit(loyalty(record).permitted_attributes)
  end

  def loyalty(record=nil, controller_name=nil)
    controller_name = banken_controller_name unless controller_name
    Banken.loyalty!(controller_name, banken_user, record)
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

    def banken_query_name
      action = banken_action_name
      if action.blank?
        raise Error, "unable to infer the query: no action name is available (authorize! must run inside a controller action)"
      end
      "#{action}?"
    end
end
