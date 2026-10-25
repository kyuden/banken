module Banken
  class LoyaltyFinder
    SUFFIX = "Loyalty"

    attr_reader :controller_name

    def initialize(controller_name)
      @controller_name = controller_name.to_s
    end

    # Returns the loyalty class, or nil when no such constant exists.
    #
    # `safe_constantize` only swallows the NameError for the constant being
    # looked up (or one of its namespaces). Any other error raised while the
    # loyalty file loads, such as a NoMethodError from a typo in the class
    # body, propagates so the real bug is visible.
    def loyalty
      loyalty_name.safe_constantize
    end

    def loyalty!
      loyalty || raise(NotDefinedError, "unable to find loyalty `#{loyalty_name}` for `#{controller_name}` (expected #{expected_path} to define it)")
    end

    private

      def loyalty_name
        "#{controller_name.camelize}#{SUFFIX}"
      end

      def expected_path
        "app/loyalties/#{controller_name}_loyalty.rb"
      end
  end
end
