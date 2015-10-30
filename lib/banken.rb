require "active_support/concern"
require "active_support/core_ext/string/inflections"
require "active_support/core_ext/object/blank"
require "active_support/core_ext/module/introspection"
require "banken/version"
require "banken/error"
require "banken/helper"
require "banken/policy_finder"

module Banken
  SUFFIX = "Policy"

  extend ActiveSupport::Concern

  included do
    helper Helper if respond_to?(:helper)
    if respond_to?(:helper_method)
      helper_method :policy
      helper_method :banken_policy_scope
      helper_method :banken_user
    end
    if respond_to?(:hide_action)
      hide_action :policy
      hide_action :policy_scope
      hide_action :policies
      hide_action :policy_scopes
      hide_action :authorize
      hide_action :verify_authorized
      hide_action :verify_policy_scoped
      hide_action :permitted_attributes
      hide_action :banken_user
      hide_action :skip_authorization
      hide_action :skip_policy_scope
    end
  end

  class << self
    def authorize(user, record, action)
      policy = policy!(user, record)

      unless policy.public_send(action)
        raise NotAuthorizedError.new(action: action, record: record, policy: policy)
      end

      true
    end

    def policy_scope(user, scope)
      policy_scope = PolicyFinder.new(scope).scope
      policy_scope.new(user, scope).resolve if policy_scope
    end

    def policy_scope!(user, scope)
      PolicyFinder.new(scope).scope!.new(user, scope).resolve
    end

    def policy(user, record)
      policy = PolicyFinder.new(record).policy
      policy.new(user, record) if policy
    end

    def policy!(user, record)
      PolicyFinder.new(record).policy!.new(user, record)
    end
  end

  def banken_policy_authorized?
    !!@_banken_policy_authorized
  end

  def banken_policy_scoped?
    !!@_banken_policy_scoped
  end

  def verify_authorized
    raise AuthorizationNotPerformedError unless banken_policy_authorized?
  end

  def verify_policy_scoped
    raise PolicyScopingNotPerformedError unless banken_policy_scoped?
  end

  def authorize(record, action=nil)
    action ||= params[:action].to_s + "?"

    @_banken_policy_authorized = true

    policy = policy(record)
    unless policy.public_send(action)
      raise NotAuthorizedError.new(action: action, record: record, policy: policy)
    end

    true
  end

  def skip_authorization
    @_banken_policy_authorized = true
  end

  def skip_policy_scope
    @_banken_policy_scoped = true
  end

  def policy_scope(scope)
    @_banken_policy_scoped = true
    banken_policy_scope(scope)
  end

  def policy(record)
    policies[record] ||= Banken.policy!(banken_user, record)
  end

  def permitted_attributes(record)
    name = record.class.to_s.demodulize.underscore
    params.require(name).permit(policy(record).permitted_attributes)
  end

  def policies
    @_banken_policies ||= {}
  end

  def policy_scopes
    @_banken_policy_scopes ||= {}
  end

  def banken_user
    current_user
  end

  private

    def banken_policy_scope(scope)
      policy_scopes[scope] ||= Banken.policy_scope!(banken_user, scope)
    end
end
