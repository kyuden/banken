module Rails
  module Generators
    class LoyaltyGenerator < NamedBase
      source_root File.expand_path('templates', __dir__)
      check_class_collision suffix: "Loyalty"

      def create_loyalty
        template 'loyalty.rb', File.join('app/loyalties', class_path, "#{file_name}_loyalty.rb")
      end

      hook_for :test_framework
    end
  end
end
