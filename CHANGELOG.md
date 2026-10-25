## Unreleased

* Documentation: README rewritten for Rails 7.1+ (`update` instead of `update_attributes`, no
  Rails 4 / strong_parameters notes), the `rescue_from` examples use
  `redirect_back_or_to(root_path, allow_other_host: false)` instead of redirecting to the `Referer`
  header (an open redirect or an `UnsafeRedirectError`, depending on the app's open-redirect
  configuration), `rescue_responses` documented as an
  alternative, inference from `controller_path` / `action_name` explained, naming caveat for an
  action called `loyalty`, `Banken.loyalty!` for use outside controllers. Added SECURITY.md.
* Packaging: the gem ships only `lib/`, README, CHANGELOG, LICENSE and SECURITY.md (no more Gemfile, Rakefile,
  gemfiles/ or CI config); `rubygems_mfa_required` is set, so publishing needs MFA; banken no longer
  requires `active_support/core_ext/module/introspection`, which it never used.
* `rails g banken:loyalty` no longer prints `error  test_unit [not found]` (or `rspec [not found]`): the
  generator asked the configured test framework for a `loyalty` generator that Banken never shipped.
  It now only creates the loyalty file; a `--test-framework` option is ignored if passed. Apps that
  defined their own `test_unit:loyalty` / `rspec:loyalty` generator must now invoke it directly.
* `loyalty` resolves the loyalty class once per controller instance (per request) instead of on
  every call; loyalty instances are still created fresh for each record and the current `banken_user`.
  The controller helper no longer goes through `Banken.loyalty!` (which is unchanged); code that
  stubbed `Banken.loyalty!` to intercept controller lookups should stub `Banken::LoyaltyFinder` instead.
* `permitted_attributes` accepts a class as the record (`permitted_attributes(Post)` reads
  `params[:post]`; it used to read `params[:class]`). Two private hooks can be overridden in the
  controller: `banken_param_key(record)` (defaults to the demodulized, underscored class name) and
  `banken_params_for(record)` (defaults to `params.require(banken_param_key(record))`).
* Infer the loyalty and the query from `controller_path` and `action_name` instead of
  `params[:controller]` / `params[:action]`, falling back to params only when they are unavailable.
  Routed requests behave as before unless the controller overrides `self.controller_path`, in which
  case the loyalty is now looked up from the overridden value. `authorize!` and `loyalty` now also
  work when a controller is dispatched directly (`PostsController.action(:index).call(env)`), and
  `loyalty` resolves inside `ActionController::Renderer` (there is no action there, so `authorize!`
  raises a `Banken::Error` explaining that instead of a `NoMethodError` for `?`).
* Security: for routes that target an endpoint directly (`get "/x" => PostsController.action(:destroy)`,
  `mount`), the path parameters carry no controller or action, so the previous inference read them
  from the query string and a request could pick which loyalty and query were checked. The loyalty
  and query now come from the controller class and the dispatched action.
* Errors raised while a loyalty file loads (for example a `NoMethodError` from a typo in the class
  body, or a `NameError` for an unrelated constant) now propagate instead of being reported as
  `Banken::NotDefinedError`. `LoyaltyFinder` uses `safe_constantize`, so only `NameError`s that name
  the loyalty constant or one of its namespaces (including Zeitwerk's "expected file to define
  constant" error for a file that defines the wrong constant name) still surface as `NotDefinedError`.
  The `NotDefinedError` message now also names the file expected to define the loyalty.
* Security: the default `Banken::NotAuthorizedError` message no longer embeds `loyalty.inspect`, which
  included the inspected user and record (every instance variable of plain Ruby objects; for Active Record
  models every attribute not covered by `filter_attributes`) and reached logs, error trackers and any
  `flash` built from the message. The message is now `not allowed to PostsLoyalty#update? on posts`.
  The `controller`, `query` and `loyalty` attributes are unchanged.
* Fix `banken_loyalty_authorized?` raising `NoMethodError` on Rails >= 7.2. Deprecation warnings now go
  through `Banken.deprecator`, which `Banken::Railtie` registers with `Rails.application.deprecators`, so
  `config.active_support.deprecation` applies to Banken. If banken is required after Rails has
  initialized (for example `require: false` plus a later `require`), register it yourself with
  `Rails.application.deprecators[:banken] = Banken.deprecator`.
* Require Ruby >= 3.3 and Rails (Active Support) >= 7.1. Older versions keep using 1.0.3.
  Supported matrix: Ruby 3.3 / 3.4 / 4.0 x Rails 7.1 / 7.2 / 8.0 / 8.1.

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
