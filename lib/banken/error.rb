module Banken
  class Error < StandardError; end

  class NotAuthorizedError < Error
    attr_reader :controller, :action, :policy

    def initialize(options = {})
      if options.is_a? String
        message = options
      else
        @controller = options[:controller]
        @action     = options[:action]
        @policy     = options[:policy]

        message = options.fetch(:message) { "not allowed to #{action} of #{controller} by #{policy.inspect}" }
      end

      super(message)
    end
  end

  class NotDefinedError < Error; end
  class AuthorizationNotPerformedError < Error; end

  class PolicyScopingNotPerformedError < AuthorizationNotPerformedError; end
end
