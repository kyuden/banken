# frozen_string_literal: true

require "active_support/concern"
require "active_support/core_ext/string/inflections"
require "active_support/core_ext/object/blank"
require "banken/version"
require "banken/error"
require "banken/loyalty_finder"
require "banken/deprecator"
require "banken/authorization"
require "banken/railtie" if defined?(::Rails::Railtie)

# Banken's controller helpers live in Banken::Authorization; include that
# module in your controllers. Including `Banken` itself still works for
# compatibility: it includes Banken::Authorization, but also brings every
# constant under this namespace into the controller's constant lookup.
module Banken
  extend ActiveSupport::Concern

  included do
    include Banken::Authorization
  end

  class << self
    def loyalty!(controller_name, user, record=nil)
      LoyaltyFinder.new(controller_name).loyalty!.new(user, record)
    end
  end
end
