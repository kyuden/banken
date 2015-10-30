module Banken
  class Error < StandardError; end

  class NotAuthorizedError < Error
    attr_reader :action, :record, :policy

    def initialize(options = {})
      if options.is_a? String
        message = options
      else
        @action  = options[:action]
        @record = options[:record]
        @policy = options[:policy]

        message = options.fetch(:message) { "not allowed to #{action} this #{record.inspect}" }
      end

      super(message)
    end
  end

  class NotDefinedError < Error; end
  class AuthorizationNotPerformedError < Error; end

  class PolicyScopingNotPerformedError < AuthorizationNotPerformedError; end
end
