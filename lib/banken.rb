require "active_support/concern"
require "active_support/core_ext/string/inflections"
require "active_support/core_ext/object/blank"
require "active_support/core_ext/module/introspection"
require "banken/version"
require "banken/error"
require "banken/loyalty_finder"
require "banken/loyalty_factory"

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

  class_methods do
    def def_banken_query_method_for(action_name, &block)
      banken_loyalty.class_eval do
        define_method("#{action_name}?", &block)
      end
    end

    private

    def banken_loyalty
      LoyaltyFinder.new(banken_controller_name).loyalty!
    rescue NotDefinedError
      LoyaltyFactory.new(self).create
    end

    def banken_controller_name
      controller_path
    end
  end

  def authorize!(record=nil)
    @_banken_loyalty_authorized = true

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
    @_banken_loyalty_authorized = true
  end

  def verify_authorized
    raise AuthorizationNotPerformedError unless banken_loyalty_authorized?
  end

  def banken_loyalty_authorized?
    !!@_banken_loyalty_authorized
  end

  private

    def banken_action_name
      params[:action]
    end

    def banken_controller_name
      params[:controller]
    end

    def banken_query_name
      "#{banken_action_name}?"
    end
end
