module Banken
  class Error < StandardError; end

  class NotAuthorizedError < Error
    attr_reader :controller, :query, :loyalty

    def initialize(options={})
      if options.is_a? String
        message = options
      else
        @controller = options[:controller]
        @query      = options[:query]
        @loyalty    = options[:loyalty]

        message = options.fetch(:message) { default_message }
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

  class LoyaltyScopingNotPerformedError < AuthorizationNotPerformedError; end
end
