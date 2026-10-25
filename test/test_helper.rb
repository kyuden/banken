require "banken"

require "active_support"
require "active_support/core_ext"
require "active_model"
require "action_controller"
require "action_controller/metal/strong_parameters"

require "minitest/autorun"
require "minitest/mock"

I18n.enforce_available_locales = false

Dir[File.expand_path("support/**/*.rb", __dir__)].sort.each { |f| require f }
