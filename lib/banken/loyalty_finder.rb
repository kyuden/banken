module Banken
  class LoyaltyFinder
    SUFFIX = "Loyalty"

    attr_reader :controller_name

    def initialize(controller_name)
      @controller_name = controller_name.to_s
    end

    def loyalty
      loyalty_name.constantize
    rescue NameError
      nil
    end

    def loyalty!
      loyalty || raise(NotDefinedError, "unable to find loyalty `#{loyalty_name}` for `#{controller_name}`")
    end

    private

      def loyalty_name
        "#{controller_name.camelize}#{SUFFIX}"
      end
  end
end
