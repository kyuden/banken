module Banken
  class LoyaltyFactory
    SUFFIX = "Loyalty"

    attr_reader :controller_name, :base_controller_name

    def initialize(controller)
      @controller_name      = extract_controller_name(controller)
      @base_controller_name = extract_controller_name(controller.superclass)
    end

    def create
      Object.const_set(loyalty_name, loyalty_klass)
    end

    private

      def extract_controller_name(controller)
        controller.controller_path if controller.to_s.end_with?("Controller")
      end

      def loyalty_name
        "#{controller_name.camelize}#{SUFFIX}"
      end

      def loyalty_klass
        if base_controller_name
          Class.new(base_loyalty)
        else
          Class.new do
            attr_reader :user, :record

            def initialize(user, record)
              @user = user
              @record = record
            end
          end
        end
      end

      def base_loyalty
        LoyaltyFinder.new(base_controller_name).loyalty!
      end
  end
end
