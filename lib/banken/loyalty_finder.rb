module Banken
  class LoyaltyFinder
    SUFFIX = "Loyalty"

    attr_reader :controller

    def initialize(controller)
      @controller = controller
    end

    def scope
      loyalty::Scope if loyalty
    rescue NameError
      nil
    end

    def loyalty
      klass = find
      klass = klass.constantize if klass.is_a?(String)
      klass
    rescue NameError
      nil
    end

    def scope!
      raise NotDefinedError, "unable to find loyalty scope of nil" unless controller
      scope || raise(NotDefinedError, "unable to find scope `#{find}::Scope` for `#{controller}`")
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
