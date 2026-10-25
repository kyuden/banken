## Unreleased

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
  the loyalty constant or one of its namespaces (including Zeitwerk\x27s "expected file to define
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

* Renamed `banken_loyalty_authorized?` to `banken_authorization_performed?` (okuramasafumi)
