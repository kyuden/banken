module Banken
  module Generators
    class InstallGenerator < ::Rails::Generators::Base
      source_root File.expand_path('templates', __dir__)

      def copy_application_loyalty
        template 'application_loyalty.rb', 'app/loyalties/application_loyalty.rb'
      end
    end
  end
end
