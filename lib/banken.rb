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
      hide_action :loyalties
    end
  end

  class << self
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

  def permitted_attributes(record)
    name = record.class.to_s.demodulize.underscore
    params.require(name).permit(loyalty(banken_controller_name, record).permitted_attributes)
  end

  def loyalty(controller_name, record=nil)
    loyalties[controller_name.to_s] ||= Banken.loyalty!(controller_name.to_s, banken_user, record)
  end

  def banken_user
    current_user
  end

  def skip_authorization
    @_banken_loyalty_authorized = true
  end

  def verify_authorized
    raise AuthorizationNotPerformedError unless banken_loyalty_authorized?
  end

  def banken_loyalty_authorized?
    !!@_banken_loyalty_authorized
  end

  def loyalties
    @_banken_loyalties ||= {}
  end

  private

    def banken_action_name
      params[:action].to_s
    end

    def banken_controller_name
      params[:controller].to_s
    end
end
