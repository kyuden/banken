# frozen_string_literal: true

module Banken
  class LoyaltyFinder
    SUFFIX = "Loyalty"

    attr_reader :controller_name

    def initialize(controller_name)
      @controller_name = controller_name.to_s
    end

    # Returns the loyalty class, or nil when no such constant exists.
    #
    # `safe_constantize` only swallows NameErrors whose name matches a segment
    # of the loyalty name (or that carry no name at all); this includes
    # Zeitwerk's "expected file to define constant" error. Any other error
    # raised while the loyalty file loads, such as a NoMethodError from a typo
    # in the class body, propagates so the real bug is visible.
    def loyalty
      loyalty_name.safe_constantize
    end

    def loyalty!
      loyalty || raise(NotDefinedError, not_defined_message)
    end

    private

      def loyalty_name
        "#{controller_name.camelize}#{SUFFIX}"
      end

      def not_defined_message
        hint = controller_name.empty? ? "" : " (expected app/loyalties/#{controller_name}_loyalty.rb to define it)"
        "unable to find loyalty `#{loyalty_name}` for `#{controller_name}`#{hint}"
      end
  end
end
