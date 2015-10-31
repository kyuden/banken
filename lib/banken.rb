require "active_support/concern"
require "active_support/core_ext/string/inflections"
require "active_support/core_ext/object/blank"
require "active_support/core_ext/module/introspection"
require "banken/version"
require "banken/error"
require "banken/loyalty_finder"

module Banken
  extend ActiveSupport::Concern

  included do
    helper Helper if respond_to?(:helper)
    if respond_to?(:helper_method)
      helper_method :loyalty
      helper_method :banken_loyalty_scope
      helper_method :banken_user
    end
    if respond_to?(:hide_action)
      hide_action :loyalty_scope
      hide_action :permitted_attributes
      hide_action :loyalty
      hide_action :banken_user
      hide_action :skip_authorization
      hide_action :skip_loyalty_scope
      hide_action :verify_authorized
      hide_action :verify_loyalty_scoped
      hide_action :policies
      hide_action :loyalty_scopes
    end
  end

  class << self
    def loyalty_scope!(controller, user, scope)
      LoyaltyFinder.new(controller).scope!.new(user, scope).resolve
    end

    def loyalty!(controller, user, record)
      LoyaltyFinder.new(controller).loyalty!.new(user, record)
    end
  end

  def authorize!(record=nil)
    @_banken_loyalty_authorized = true

    loyalty = loyalty(banken_controller_name, record)
    unless loyalty.public_send("#{banken_action_name}?")
      raise NotAuthorizedError.new(controller: banken_controller_name, action: banken_action_name, loyalty: loyalty)
    end

    true
  end

  module Helper
    def loyalty_scope(controller_name, scope)
      banken_loyalty_scope(controller_name.to_s, scope)
    end
  end

  def loyalty_scope(scope)
    @_banken_loyalty_scoped = true
    banken_loyalty_scope(banken_controller_name, scope)
  end

  def permitted_attributes(record)
    name = record.class.to_s.demodulize.underscore
    params.require(name).permit(loyalty(banken_controller_name, record).permitted_attributes)
  end

  def loyalty(controller_name, record=nil)
    policies[controller_name.to_s] ||= Banken.loyalty!(controller_name.to_s, banken_user, record)
  end

  def banken_user
    current_user
  end

  def skip_authorization
    @_banken_loyalty_authorized = true
  end

  def skip_loyalty_scope
    @_banken_loyalty_scoped = true
  end

  def verify_authorized
    raise AuthorizationNotPerformedError unless banken_loyalty_authorized?
  end

  def verify_loyalty_scoped
    raise LoyaltyScopingNotPerformedError unless banken_loyalty_scoped?
  end

  def banken_loyalty_authorized?
    !!@_banken_loyalty_authorized
  end

  def banken_loyalty_scoped?
    !!@_banken_loyalty_scoped
  end

  def policies
    @_banken_policies ||= {}
  end

  def loyalty_scopes
    @_banken_loyalty_scopes ||= {}
  end

  private

    def banken_loyalty_scope(controller_name, scope)
      loyalty_scopes[scope] ||= Banken.loyalty_scope!(controller_name, banken_user, scope)
    end

    def banken_action_name
      params[:action].to_s
    end

    def banken_controller_name
      params[:controller].to_s
    end
end
