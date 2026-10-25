# frozen_string_literal: true

module Banken
  class Railtie < ::Rails::Railtie
    initializer "banken.deprecator" do |app|
      app.deprecators[:banken] = Banken.deprecator
    end
  end
end
