module Banken
  class LoyaltyFinder
    SUFFIX = "Loyalty"

    attr_reader :controller

    def initialize(controller)
      @controller = controller
    end

    def loyalty
      klass = find
      klass = klass.constantize if klass.is_a?(String)
      klass
    rescue NameError
      nil
    end

    def loyalty!
      raise NotDefinedError, "unable to find loyalty of nil" unless controller
      loyalty || raise(NotDefinedError, "unable to find loyalty `#{find}` for `#{controller}`")
    end

    private

      def find
        "#{controller.camelize}#{SUFFIX}"
      end
  end
end
