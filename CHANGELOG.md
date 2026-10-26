## 1.1.0 (2026-10-26)

Requires Ruby >= 3.3 and Rails >= 7.1. No public methods or constants were removed. CI covers
Ruby 3.3 / 3.4 / 4.0 x Rails 7.1 / 7.2 / 8.0 / 8.1.

### Upgrading from 1.0.x

No breaking changes to the public API: no method, constant or argument was removed or changed
its signature, `include Banken` keeps working unchanged (`include Banken::Authorization` is the
recommended form from now on), and an application that upgrades without touching its code keeps
authorizing the same requests. What follows are behaviour changes, most of them closing security
gaps or replacing confusing errors with clear ones, that can affect code or tests relying on the
old behaviour. Details in the sections below.

* The default `Banken::NotAuthorizedError` message changed from
  `not allowed to update? of posts by #<PostsLoyalty ...>` to
  `not allowed to PostsLoyalty#update? on posts`. Code or tests matching on the message text
  must change; the `controller`, `query` and `loyalty` attributes are unchanged.
* A query the loyalty does not define raises `Banken::QueryNotDefinedError` (a subclass of
  `NotDefinedError`) instead of `NoMethodError`; code rescuing or asserting `NoMethodError` there
  must change, and a `rescue_from Banken::NotDefinedError` now also catches it. Queries inherited
  from `Object` (an action named `present` or `duplicable`) and private queries raise it too.
* Anonymous controllers (`controller_path` nil) raise `NotDefinedError` from `authorize!` and
  `loyalty`; pass the controller name explicitly (`loyalty(record, :posts)`). On a Rails controller
  `params[:controller]` / `params[:action]` are never consulted any more.
* Banken's helpers (`authorize!`, `loyalty`, `skip_authorization`, `verify_authorized`,
  `banken_user`, `permitted_attributes`, `banken_authorization_performed?`,
  `banken_loyalty_authorized?`) are no longer routable actions, and neither is an application
  action that carries one of those names.
* The `Banken::AuthorizationNotPerformedError` message changed from the bare class name to
  `PostsController#update did not call authorize! or skip_authorization`.
* `NotAuthorizedError#controller` (and the messages) carry `controller_path`, which differs from
  the old `params[:controller]` when the controller overrides `self.controller_path` or when the
  route name does not round-trip through camelize/underscore (`users_2fa` -> `Users2faController`
  -> `users2fa`). The loyalty resolved is the same.
* `permitted_attributes`: a scalar or array params value raises `ActionController::ParameterMissing`
  (400) instead of `NoMethodError` (500); `nil` and anonymous classes raise `ArgumentError`; the
  params key is derived from the class's `name` (no longer `to_s`), which matters only for classes
  overriding one of them.
* Errors raised while a loyalty file loads now propagate instead of becoming
  `Banken::NotDefinedError`; a `rescue_from Banken::NotDefinedError` no longer catches them.
* The controller `loyalty` helper no longer calls `Banken.loyalty!`; stubs on `Banken.loyalty!`
  stop intercepting controller lookups (stub `Banken::LoyaltyFinder` instead). The memoized loyalty
  class is kept in `@_banken_loyalty_classes`, which shows up in `view_assigns` / `assigns` next to
  the existing `@_banken_authorization_performed`.
* `config.action_dispatch.rescue_responses` matches exact class names (Rails behaviour): a mapping
  for `Banken::NotDefinedError` does not cover `Banken::QueryNotDefinedError`.
* `rails g banken:loyalty` no longer invokes a `test_framework` generator; a custom
  `test_unit:loyalty` / `rspec:loyalty` generator must be invoked directly.
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
* `authorize!` only consults queries defined by the loyalty itself (or a module or superclass below
  `Object`). ActiveSupport defines `present?` and `duplicable?` on every object and both return
  `true`, so an action named `present` or `duplicable` passed `authorize!` with a loyalty that
  defined nothing. Such queries, undefined queries and private queries now raise
  `Banken::QueryNotDefinedError`; queries answered through `method_missing` keep working.
* For routes that target an endpoint directly (`get "/x" => PostsController.action(:destroy)`,
  `mount`), the path parameters carry no controller or action, so the previous inference read them
  from the query string and a request could pick which loyalty and query were checked. The loyalty
  and query now come from the controller class and the dispatched action.
* On a Rails controller, `params[:controller]` / `params[:action]` are never consulted any more.
  Anonymous controllers (`controller_path` nil) used to fall back to `params[:controller]`, which
  comes from the query string there, letting a request choose the loyalty. They now raise
  `NotDefinedError`; pass the controller name to `loyalty` explicitly.
* Banken's helpers are excluded from the controller's `action_methods`, so routes with a dynamic
  `:action` segment can no longer dispatch to `skip_authorization`, `verify_authorized` and the
  others. Same as Pundit #269 / #357.

### Added

* `Banken::Authorization`, the controller mixin. Prefer `include Banken::Authorization` over
  `include Banken`: including the top-level module also makes every constant under `Banken` (`Error`,
  `VERSION`, `LoyaltyFinder`, `Railtie`, ...) resolvable inside the controller, shadowing application
  constants of the same name. `include Banken` keeps working (it includes `Banken::Authorization`)
  and will be deprecated in 2.0. Same motivation as Pundit 2.2.0's `Pundit::Authorization`.
* `Banken::QueryNotDefinedError < Banken::NotDefinedError`, raised when the loyalty exists but the
  query is undefined, private or inherited from `Object`.
* `Banken.deprecator`, an `ActiveSupport::Deprecation` instance, and `Banken::Railtie`, which
  registers it with `Rails.application.deprecators` so `config.active_support.deprecation` applies
  to Banken (its `:notify` events are published as `deprecation.banken`). If banken is required
  after Rails has initialized (for example `require: false` plus a later `require`), register it
  yourself with `Rails.application.deprecators[:banken] = Banken.deprecator`.
* Two private hooks overridable in the controller: `banken_param_key(record)` (defaults to the
  demodulized, underscored class name) and `banken_params_for(record)` (defaults to
  `params.require(banken_param_key(record))`).
* `permitted_attributes` accepts a class or a Symbol as the record (`permitted_attributes(Post)` and
  `permitted_attributes(:post)` both read `params[:post]`).

### Fixed

* `banken_loyalty_authorized?` raised `NoMethodError` on Rails >= 7.2 because it called the
  removed `ActiveSupport::Deprecation` singleton. It now warns through `Banken.deprecator`.
* Errors raised while a loyalty file loads (for example a `NoMethodError` from a typo in the class
  body, or a `NameError` for an unrelated constant) now propagate instead of being reported as
  `Banken::NotDefinedError`. `LoyaltyFinder` uses `safe_constantize`, so only `NameError`s that name
  the loyalty constant or one of its namespaces (including Zeitwerk's "expected file to define
  constant" error for a file that defines the wrong constant name) still surface as `NotDefinedError`.
  The `NotDefinedError` message now also names the file expected to define the loyalty.
* `permitted_attributes(Post)` reads `params[:post]` (it used to read `params[:class]`); a scalar or
  array value raises `ActionController::ParameterMissing` (400) instead of `NoMethodError` (500);
  `nil` raises `ArgumentError` instead of reading `params[:nil_class]`; an anonymous class raises
  `ArgumentError`.
* `verify_authorized` says which controller and action forgot to authorize
  (`PostsController#update did not call authorize! or skip_authorization`).
* An empty controller name no longer resolves a top-level `Loyalty` constant; `Banken.loyalty!(nil, ...)`
  raises `NotDefinedError` ("no controller name was given").
* `Banken::NotAuthorizedError.new` accepts any non-Hash argument as the message (e.g. `nil` or a
  Symbol) instead of raising `NoMethodError`.
* `rails g banken:loyalty` no longer prints `error  test_unit [not found]` (or `rspec [not found]`):
  the generator asked the configured test framework for a `loyalty` generator that Banken never
  shipped. It now only creates the loyalty file; a `--test-framework` option is ignored if passed.

### Changed

* The loyalty and the query are inferred from `controller_path` and `action_name` instead of
  `params[:controller]` / `params[:action]`; params are read only on hosts that provide neither
  (plain Ruby objects). Routed requests resolve the same loyalty as before; `NotAuthorizedError#controller`
  is now `controller_path`, which differs from `params[:controller]` when the controller overrides
  `self.controller_path` (the loyalty is then looked up from the overridden value) or when the route
  name does not round-trip through camelize/underscore (`users_2fa` -> `users2fa`). `authorize!` and
  `loyalty` now also work when a controller is dispatched directly
  (`PostsController.action(:index).call(env)`), and `loyalty` resolves inside
  `ActionController::Renderer` (there is no action there, so `authorize!` raises a `Banken::Error`
  explaining that instead of a `NoMethodError` for `?`).
* `loyalty` resolves the loyalty class once per controller instance (per request) instead of on
  every call; loyalty instances are still created fresh for each record and the current
  `banken_user`. The controller helper no longer goes through `Banken.loyalty!` (which is unchanged).
* `permitted_attributes` derives the params key from the class's `name` instead of `record.class.to_s`.

### Deprecated (removal planned for 2.0)

* `include Banken` in controllers (use `include Banken::Authorization`); no warning is emitted yet.
* `banken_loyalty_authorized?` (use `banken_authorization_performed?`); it now warns through
  `Banken.deprecator`.
* `Banken::LoyaltyScopingNotPerformedError`, which nothing raises.

### Packaging and documentation

* The gem ships only `lib/`, README, CHANGELOG, LICENSE and SECURITY.md (no more Gemfile, Rakefile,
  gemfiles/ or CI config); `rubygems_mfa_required` is set, so publishing needs MFA; banken no longer
  requires `active_support/core_ext/module/introspection`, which it never used. Generator templates
  are shipped as `.rb.tt` files, the Rails convention.
* README rewritten for Rails 7.1+ (`update` instead of `update_attributes`, no Rails 4 /
  strong_parameters notes), the `rescue_from` examples use
  `redirect_back_or_to(root_path, allow_other_host: false)` instead of redirecting to the `Referer`
  header (an open redirect or an `UnsafeRedirectError`, depending on the app's open-redirect
  configuration), `rescue_responses` documented as an alternative, inference from `controller_path` /
  `action_name` explained, naming caveat for an action called `loyalty`, `Banken.loyalty!` for use
  outside controllers, `after_action :verify_authorized` without `except: :index` (Banken has no
  scopes), the `UserContext` example returns nil for anonymous requests so a "must be logged in"
  guard still works, queries must return booleans, `permitted_attributes` uses the current
  controller's loyalty, never pass request data as the controller name to `loyalty`. Added SECURITY.md.

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
