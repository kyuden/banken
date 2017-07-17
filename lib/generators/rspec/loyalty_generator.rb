module Rspec
  module Generators
    class LoyaltyGenerator < ::Rails::Generators::NamedBase
      source_root File.expand_path('templates', __dir__)

      def create_spec_file
        template "loyalty_spec.rb", File.join("spec/loyalties", class_path, "#{file_name}_loyalty_spec.rb")
      end
    end
  end
end
