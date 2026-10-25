# frozen_string_literal: true

require "active_support/deprecation"

module Banken
  # Banken's own deprecator. When banken is loaded after Rails (the normal
  # Bundler.require order), Banken::Railtie registers it with
  # `Rails.application.deprecators`, so the application's
  # `config.active_support.deprecation` setting applies to Banken's warnings.
  # Outside Rails, or when banken is required after Rails has initialized, it
  # falls back to ActiveSupport's default behaviour (stderr); such apps can
  # register it themselves: `Rails.application.deprecators[:banken] = Banken.deprecator`.
  #
  # Assigned eagerly rather than memoized so there is exactly one instance
  # regardless of thread timing.
  @deprecator = ActiveSupport::Deprecation.new("2.0", "Banken")

  class << self
    attr_reader :deprecator
  end
end
