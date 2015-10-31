module Banken
  class LoyaltyFinder
    SUFFIX = "Loyalty"

    attr_reader :controller

    def initialize(controller)
      @controller = controller.to_s
    end

    def loyalty
      loyalty_name.constantize
    rescue NameError
      nil
    end

    def loyalty!
      raise NotDefinedError, "unable to find loyalty of nil" unless controller
      loyalty || raise(NotDefinedError, "unable to find loyalty `#{loyalty_name}` for `#{controller}`")
    end

    private

      def loyalty_name
        "#{controller.camelize}#{SUFFIX}"
      end
  end
end
