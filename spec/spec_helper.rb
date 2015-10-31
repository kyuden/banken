require "banken"

require "rack"
require "rack/test"
require "active_support"
require "active_support/core_ext"
require "action_controller/metal/strong_parameters"

require "pry"

I18n.enforce_available_locales = false

$:.unshift File.expand_path('../support', __FILE__)
Dir["#{File.dirname(__FILE__)}/support/**/**/*.rb"].each { |f| require f }
