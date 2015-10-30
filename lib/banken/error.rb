module Banken
  class Error < StandardError; end

  class NotAuthorizedError < Error
    attr_reader :controller, :action, :loyalty

    def initialize(options={})
      if options.is_a? String
        message = options
      else
        @controller = options[:controller]
        @action     = options[:action]
        @loyalty     = options[:loyalty]

        message = options.fetch(:message) { "not allowed to #{action} of #{controller} by #{loyalty.inspect}" }
      end

      super(message)
    end
  end

  class NotDefinedError < Error; end
  class AuthorizationNotPerformedError < Error; end

  class LoyaltyScopingNotPerformedError < AuthorizationNotPerformedError; end
end
