# frozen_string_literal: true

require "active_support/concern"

module Banken
  # The controller mixin. Include this module, not `Banken` itself:
  #
  #   class ApplicationController < ActionController::Base
  #     include Banken::Authorization
  #   end
  #
  # `include Banken` keeps working, but it also makes every constant under the
  # Banken namespace (Error, VERSION, LoyaltyFinder, Railtie, ...) resolvable
  # inside the controller, shadowing application constants of the same name.
  module Authorization
    extend ActiveSupport::Concern

    included do
      if respond_to?(:helper_method)
        helper_method :loyalty
        helper_method :banken_user
      end
    end

    # Rails treats every public instance method of a non-abstract controller
    # as a routable action. Keep Banken's helpers out of that set, so a
    # wildcard route such as `get "posts/:action"` cannot dispatch to
    # `skip_authorization` or `verify_authorized`.
    class_methods do
      def action_methods
        @_banken_action_methods ||= super - Banken::Authorization::HIDDEN_ACTIONS
      end

      def clear_action_methods!
        @_banken_action_methods = nil
        super
      end
    end

    def authorize!(record=nil)
      @_banken_authorization_performed = true

      loyalty = loyalty(record)
      query   = banken_query_name

      unless banken_query(loyalty, query)
        raise Banken::NotAuthorizedError.new(controller: banken_controller_name, query: query, loyalty: loyalty)
      end

      true
    end

    def permitted_attributes(record)
      attributes = banken_params_for(record)
      unless attributes.respond_to?(:permit)
        # A scalar or an array where a hash of attributes was expected.
        raise ActionController::ParameterMissing, banken_param_key(record)
      end
      attributes.permit(loyalty(record).permitted_attributes)
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
      return if banken_authorization_performed?

      where = [self.class.name, banken_action_name.presence].compact.join("#")
      raise Banken::AuthorizationNotPerformedError, "#{where} did not call authorize! or skip_authorization"
    end

    def banken_authorization_performed?
      !!@_banken_authorization_performed
    end

    # @deprecated Use banken_authorization_performed? instead.
    def banken_loyalty_authorized?
      Banken.deprecator.warn('banken_loyalty_authorized? is deprecated, use banken_authorization_performed? instead.')
      banken_authorization_performed?
    end

    # The public helpers above, by name. Computed here so that it always
    # matches what the module actually defines.
    HIDDEN_ACTIONS = public_instance_methods(false).map(&:to_s).sort.freeze

    private

      # Rails sets action_name and controller_path on every controller and, unlike
      # params[:controller] / params[:action], they cannot be supplied by the
      # request. On a Rails controller only those are consulted: for routes that
      # target an endpoint directly (`get "/x" => PostsController.action(:destroy)`,
      # `mount`) and for anonymous controllers the path parameters carry no
      # controller or action, and reading params there would let the query
      # string choose the loyalty. params are the source only for hosts that do
      # not provide action_name / controller_path at all (plain Ruby objects).
      def banken_action_name
        if respond_to?(:action_name)
          action_name.presence
        else
          params[:action]
        end
      end

      def banken_controller_name
        if respond_to?(:controller_path)
          controller_path.presence || raise(Banken::NotDefinedError, "#{self.class} has no controller_path (anonymous controller?); pass the controller name to loyalty explicitly")
        else
          params[:controller]
        end
      end

      # Calls the query on the loyalty. A query must be defined by the loyalty
      # itself (or a module/superclass of it below Object): ActiveSupport
      # defines `present?` and `duplicable?` on every object and both return
      # true, so an action named `present` would otherwise authorize everyone.
      # Queries answered through method_missing keep working. A missing or
      # private query raises QueryNotDefinedError instead of NoMethodError.
      def banken_query(loyalty, query)
        owner = banken_query_owner(loyalty, query)
        if owner && Object <= owner
          raise Banken::QueryNotDefinedError, "#{loyalty.class}##{query} is not defined by the loyalty (inherited from #{owner})"
        end

        loyalty.public_send(query)
      rescue NoMethodError => e
        raise unless e.name == query.to_sym && e.receiver.equal?(loyalty)

        if loyalty.respond_to?(query, true)
          raise Banken::QueryNotDefinedError, "#{loyalty.class}##{query} is private; queries must be public methods"
        end
        raise Banken::QueryNotDefinedError, "#{loyalty.class}##{query} is not defined"
      end

      # The module that defines the query, or nil when it is not a statically
      # defined method (method_missing, or a loyalty overriding respond_to?).
      def banken_query_owner(loyalty, query)
        loyalty.method(query).owner
      rescue NameError
        nil
      end

      # Resolving a loyalty class means camelizing and constantizing the controller
      # name (a few microseconds, more for namespaced names); a view may do that
      # dozens of times per request. Memoize the class per controller instance (i.e. per request), so
      # code reloading in development still sees new classes on the next request.
      # Only the class is memoized, never the instance: a loyalty is built fresh
      # for every record and for the current banken_user.
      def banken_loyalty_class(controller_name)
        @_banken_loyalty_classes ||= {}
        @_banken_loyalty_classes[controller_name.to_s] ||= Banken::LoyaltyFinder.new(controller_name).loyalty!
      end

      # The parameters that hold the attributes of `record`, before filtering.
      # Override (keep it private) to read them from somewhere else; return an
      # ActionController::Parameters.
      def banken_params_for(record)
        params.require(banken_param_key(record))
      end

      # The params key for `record`, which may be an instance, a class or a
      # Symbol: Post / Post.new -> "post", Admin::Post -> "post", :post -> "post".
      # Override (keep it private) to use e.g. `record.model_name.param_key`
      # ("admin_post").
      def banken_param_key(record)
        return record.to_s if record.is_a?(Symbol)
        raise ArgumentError, "cannot infer a params key for nil; pass a record, a class or a Symbol" if record.nil?

        klass = record.is_a?(Class) ? record : record.class
        name  = klass.name || raise(ArgumentError, "cannot infer a params key for an anonymous class")
        name.demodulize.underscore
      end

      def banken_query_name
        action = banken_action_name
        if action.blank?
          raise Banken::Error, "unable to infer the query: no action name is available (authorize! must run inside a controller action)"
        end
        "#{action}?"
      end
  end
end
