module Banken
  class PolicyFinder
    SUFFIX = "Policy"

    attr_reader :object

    def initialize(controller)
      @controller = controller
    end

    def scope
      policy::Scope if policy
    rescue NameError
      nil
    end

    def policy
      klass = find
      klass = klass.constantize if klass.is_a?(String)
      klass
    rescue NameError
      nil
    end

    def scope!
      raise NotDefinedError, "unable to find policy scope of nil" if object.nil?
      scope || raise(NotDefinedError, "unable to find scope `#{find}::Scope` for `#{object.inspect}`")
    end

    def policy!
      raise NotDefinedError, "unable to find policy scope of nil" unless @controller
      policy || raise(NotDefinedError, "unable to find policy `#{find}` for `#{@controller}`")
    end

  private

    def find
      "#{@controller.camelize}#{SUFFIX}"
    end
  end
end
