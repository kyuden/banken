module Banken
  module Generators
    class LoyaltyGenerator < ::Rails::Generators::NamedBase
      source_root File.expand_path(File.join(File.dirname(__FILE__), 'templates'))

      def create_loyalty
        template 'loyalty.rb', File.join('app/loyalties', class_path, "#{file_name}_loyalty.rb")
      end

      hook_for :test_framework
    end
  end
end
