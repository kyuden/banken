require "active_support/concern"
require "active_support/core_ext/string/inflections"
require "active_support/core_ext/object/blank"
require "active_support/core_ext/module/introspection"
require "banken/version"
require "banken/error"
require "banken/helper"
require "banken/policy_finder"

module Banken
  extend ActiveSupport::Concern

  included do
    # TODO
    # helper Helper if respond_to?(:helper)
    if respond_to?(:helper_method)
      # TODO
      # helper_method :banken_policy_scope
      helper_method :banken_user
    end
    if respond_to?(:hide_action)
      hide_action :policy_scope
      hide_action :permitted_attributes
      hide_action :policy
      hide_action :banken_user
      hide_action :skip_authorization
      hide_action :skip_policy_scope
      hide_action :verify_authorized
      hide_action :verify_policy_scoped
      hide_action :policies
      hide_action :policy_scopes
    end
  end

  class << self
    def policy_scope!(controller, user, scope)
      PolicyFinder.new(controller).scope!.new(user, scope).resolve
    end

    def policy!(controller, user, record)
      PolicyFinder.new(controller).policy!.new(user, record)
    end
  end

  def authorize!(record=nil)
    @_banken_policy_authorized = true

    policy = policy(record)
    unless policy.public_send("#{banken_action_name}?")
      raise NotAuthorizedError.new(controller: banken_controller_name, action: banken_action_name, policy: policy)
    end

    true
  end

  def policy_scope(scope)
    @_banken_policy_scoped = true
    banken_policy_scope(scope)
  end

  def permitted_attributes(record)
    name = record.class.to_s.demodulize.underscore
    params.require(name).permit(policy(record).permitted_attributes)
  end

  def policy(record)
    policies[banken_action_name] ||= Banken.policy!(banken_controller_name, banken_user, record)
  end

  def banken_user
    current_user
  end

  def skip_authorization
    @_banken_policy_authorized = true
  end

  def skip_policy_scope
    @_banken_policy_scoped = true
  end

  def verify_authorized
    raise AuthorizationNotPerformedError unless banken_policy_authorized?
  end

  def verify_policy_scoped
    raise PolicyScopingNotPerformedError unless banken_policy_scoped?
  end

  def banken_policy_authorized?
    !!@_banken_policy_authorized
  end

  def banken_policy_scoped?
    !!@_banken_policy_scoped
  end

  def policies
    @_banken_policies ||= {}
  end

  def policy_scopes
    @_banken_policy_scopes ||= {}
  end

  private

    def banken_policy_scope(scope)
      policy_scopes[scope] ||= Banken.policy_scope!(banken_controller_name, banken_user, scope)
    end

    def banken_action_name
      params[:action].to_s
    end

    def banken_controller_name
      params[:controller].to_s
    end
end
