# frozen_string_literal: true

module Banken
  class Error < StandardError; end

  class NotAuthorizedError < Error
    attr_reader :controller, :query, :loyalty

    # Accepts either a message (`raise Banken::NotAuthorizedError, "must be
    # logged in"`) or an options hash with :controller, :query, :loyalty and
    # an optional :message.
    def initialize(options={})
      if options.is_a?(Hash)
        @controller = options[:controller]
        @query      = options[:query]
        @loyalty    = options[:loyalty]

        message = options.fetch(:message) { default_message }
      else
        message = options
      end

      super(message)
    end

    private

      # Names only the loyalty class, the query and the controller. Never
      # inspects the loyalty: its user and record would end up in logs, error
      # trackers and any flash built from the message.
      def default_message
        action = loyalty ? "#{loyalty.class}##{query}" : query.to_s
        parts  = ["not allowed to", action, controller && "on #{controller}"]
        parts.reject { |part| part.nil? || part.empty? }.join(" ")
      end
  end

  class NotDefinedError < Error; end
  class AuthorizationNotPerformedError < Error; end

  # Unused: Banken has no scope feature. Kept for compatibility, removed in 2.0.
  class LoyaltyScopingNotPerformedError < AuthorizationNotPerformedError; end
end
