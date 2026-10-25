# frozen_string_literal: true

module Banken
  class LoyaltyFinder
    SUFFIX = "Loyalty"

    attr_reader :controller_name

    def initialize(controller_name)
      @controller_name = controller_name.to_s
    end

    # Returns the loyalty class, or nil when no such constant exists (or when
    # no controller name was given: an empty name must not resolve a
    # top-level `Loyalty` constant).
    #
    # `safe_constantize` only swallows NameErrors whose name matches a segment
    # of the loyalty name (or that carry no name at all); this includes
    # Zeitwerk's "expected file to define constant" error. Any other error
    # raised while the loyalty file loads, such as a NoMethodError from a typo
    # in the class body, propagates so the real bug is visible.
    def loyalty
      return nil if controller_name.empty?

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
        if controller_name.empty?
          "unable to find a loyalty: no controller name was given"
        else
          "unable to find loyalty `#{loyalty_name}` for `#{controller_name}` (expected app/loyalties/#{controller_name}_loyalty.rb to define it)"
        end
      end
  end
end
