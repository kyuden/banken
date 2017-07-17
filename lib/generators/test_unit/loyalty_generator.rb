module TestUnit
  module Generators
    class LoyaltyGenerator < ::Rails::Generators::NamedBase
      source_root File.expand_path('templates', __dir__)
      check_class_collision suffix: "LoyaltyTest"

      def create_test_file
        template "loyalty_test.rb", File.join("test/loyalties", class_path, "#{file_name}_loyalty_test.rb")
      end
    end
  end
end
