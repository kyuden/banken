require "active_support/deprecation"

module Banken
  # Banken's own deprecator. Inside a Rails application it is registered with
  # `Rails.application.deprecators` (see Banken::Railtie), so the application's
  # `config.active_support.deprecation` setting applies to Banken's warnings.
  # Outside Rails it falls back to ActiveSupport's default behaviour (stderr).
  #
  # Assigned eagerly rather than memoized so there is exactly one instance
  # regardless of thread timing.
  @deprecator = ActiveSupport::Deprecation.new("2.0", "Banken")

  class << self
    attr_reader :deprecator
  end
end
