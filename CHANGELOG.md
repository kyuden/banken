## Unreleased

* Fix `banken_loyalty_authorized?` raising `NoMethodError` on Rails >= 7.2. Deprecation warnings now go
  through `Banken.deprecator`, which `Banken::Railtie` registers with `Rails.application.deprecators`, so
  `config.active_support.deprecation` applies to Banken. If banken is required after Rails has
  initialized (for example `require: false` plus a later `require`), register it yourself with
  `Rails.application.deprecators[:banken] = Banken.deprecator`.
* Require Ruby >= 3.3 and Rails (Active Support) >= 7.1. Older versions keep using 1.0.3.
  Supported matrix: Ruby 3.3 / 3.4 / 4.0 x Rails 7.1 / 7.2 / 8.0 / 8.1.

## 1.0.3 (2019-01-14)

* Renamed `banken_loyalty_authorized?` to `banken_authorization_performed?` (okuramasafumi)
