## 1.1.0 (2026-10-26)

Requires Ruby >= 3.3 and Rails >= 7.1. No public methods or constants were removed. CI covers
Ruby 3.3 / 3.4 / 4.0 x Rails 7.1 / 7.2 / 8.0 / 8.1.

### Upgrading from 1.0.x

Things an upgrader may have to act on; details in the sections below.

* The default `Banken::NotAuthorizedError` message changed from
  `not allowed to update? of posts by #<PostsLoyalty ...>` to
  `not allowed to PostsLoyalty#update? on posts`. Code or tests matching on the message text
  must change; the `controller`, `query` and `loyalty` attributes are unchanged.
* Errors raised while a loyalty file loads now propagate instead of becoming
  `Banken::NotDefinedError`; a `rescue_from Banken::NotDefinedError` no longer catches them.
* A controller that overrides `self.controller_path` now resolves its loyalty from the
  overridden value.
* The controller `loyalty` helper no longer calls `Banken.loyalty!`; stubs on `Banken.loyalty!`
  stop intercepting controller lookups (stub `Banken::LoyaltyFinder` instead).
* `rails g banken:loyalty` no longer invokes a `test_framework` generator; a custom
  `test_unit:loyalty` / `rspec:loyalty` generator must be invoked directly.
* `permitted_attributes` with an anonymous class raises `ArgumentError` (it used to produce a
  nonsense params key and `ActionController::ParameterMissing`).
* Ruby < 3.3 and Rails < 7.1 are no longer supported; such environments keep resolving 1.0.3.

### Requirements

* Ruby >= 3.3 and Rails (Active Support) >= 7.1. Supported matrix: Ruby 3.3 / 3.4 / 4.0 x Rails
  7.1 / 7.2 / 8.0 / 8.1. Environments below these floors keep resolving 1.0.3.

### Security

* The default `Banken::NotAuthorizedError` message no longer embeds `loyalty.inspect`, which
  included the inspected user and record (every instance variable of plain Ruby objects; for Active
  Record models every attribute not covered by `filter_attributes`) and reached logs, error trackers
  and any `flash` built from the message. The message is now `not allowed to PostsLoyalty#update? on
  posts`. The `controller`, `query` and `loyalty` attributes are unchanged.
* For routes that target an endpoint directly (`get "/x" => PostsController.action(:destroy)`,
  `mount`), the path parameters carry no controller or action, so the previous inference read them
  from the query string and a request could pick which loyalty and query were checked. The loyalty
  and query now come from the controller class and the dispatched action.

### Added

* `Banken.deprecator`, an `ActiveSupport::Deprecation` instance, and `Banken::Railtie`, which
  registers it with `Rails.application.deprecators` so `config.active_support.deprecation` applies
  to Banken. If banken is required after Rails has initialized (for example `require: false` plus a
  later `require`), register it yourself with `Rails.application.deprecators[:banken] = Banken.deprecator`.
* Two private hooks overridable in the controller: `banken_param_key(record)` (defaults to the
  demodulized, underscored class name) and `banken_params_for(record)` (defaults to
  `params.require(banken_param_key(record))`).

### Fixed

* `banken_loyalty_authorized?` raised `NoMethodError` on Rails >= 7.2 because it called the
  removed `ActiveSupport::Deprecation` singleton. It now warns through `Banken.deprecator`.
* Errors raised while a loyalty file loads (for example a `NoMethodError` from a typo in the class
  body, or a `NameError` for an unrelated constant) now propagate instead of being reported as
  `Banken::NotDefinedError`. `LoyaltyFinder` uses `safe_constantize`, so only `NameError`s that name
  the loyalty constant or one of its namespaces (including Zeitwerk's "expected file to define
  constant" error for a file that defines the wrong constant name) still surface as `NotDefinedError`.
  The `NotDefinedError` message now also names the file expected to define the loyalty.
* `permitted_attributes` accepts a class as the record (`permitted_attributes(Post)` reads
  `params[:post]`; it used to read `params[:class]`). An anonymous class raises `ArgumentError`.
* `rails g banken:loyalty` no longer prints `error  test_unit [not found]` (or `rspec [not found]`):
  the generator asked the configured test framework for a `loyalty` generator that Banken never
  shipped. It now only creates the loyalty file; a `--test-framework` option is ignored if passed.

### Changed

* The loyalty and the query are inferred from `controller_path` and `action_name` instead of
  `params[:controller]` / `params[:action]`, falling back to params only when they are unavailable.
  Routed requests behave as before unless the controller overrides `self.controller_path`, in which
  case the loyalty is now looked up from the overridden value. `authorize!` and `loyalty` now also
  work when a controller is dispatched directly (`PostsController.action(:index).call(env)`), and
  `loyalty` resolves inside `ActionController::Renderer` (there is no action there, so `authorize!`
  raises a `Banken::Error` explaining that instead of a `NoMethodError` for `?`).
* `loyalty` resolves the loyalty class once per controller instance (per request) instead of on
  every call; loyalty instances are still created fresh for each record and the current
  `banken_user`. The controller helper no longer goes through `Banken.loyalty!` (which is unchanged).

### Deprecated (removal planned for 2.0)

* `banken_loyalty_authorized?` (use `banken_authorization_performed?`); it now warns through
  `Banken.deprecator`.
* `Banken::LoyaltyScopingNotPerformedError`, which nothing raises.

### Packaging and documentation

* The gem ships only `lib/`, README, CHANGELOG, LICENSE and SECURITY.md (no more Gemfile, Rakefile,
  gemfiles/ or CI config); `rubygems_mfa_required` is set, so publishing needs MFA; banken no longer
  requires `active_support/core_ext/module/introspection`, which it never used.
* README rewritten for Rails 7.1+ (`update` instead of `update_attributes`, no Rails 4 /
  strong_parameters notes), the `rescue_from` examples use
  `redirect_back_or_to(root_path, allow_other_host: false)` instead of redirecting to the `Referer`
  header (an open redirect or an `UnsafeRedirectError`, depending on the app's open-redirect
  configuration), `rescue_responses` documented as an alternative, inference from `controller_path` /
  `action_name` explained, naming caveat for an action called `loyalty`, `Banken.loyalty!` for use
  outside controllers. Added SECURITY.md.

## 1.0.3 (2019-01-14)

* Renamed `banken_loyalty_authorized?` to `banken_authorization_performed?`; the old name emits a
  deprecation warning (okuramasafumi)
* README: how to call a namespaced loyalty from a view (`loyalty(@post, 'admin/posts')`)

## 1.0.2 (2016-01-30)

* Removed the loyalty cache and the public `loyalties` method; `loyalty` builds a new instance on every
  call (the 1.0.1 cache ignored the controller name)

## 1.0.1 (2016-01-30)

* Fixed `loyalty` returning the same instance for different records: the cache, keyed per controller
  since 1.0.0, is now keyed by record (#1, tkawa)

## 1.0.0 (2015-12-05)

* First stable release: `authorize!`, `loyalty`, `permitted_attributes`, `verify_authorized`,
  `skip_authorization`, `banken_user`, `banken:install` and `banken:loyalty` generators
