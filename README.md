<img width="350" src="https://raw.github.com/wiki/kyuden/banken/images/banken.png">

[![CI](https://github.com/kyuden/banken/actions/workflows/ci.yml/badge.svg)](https://github.com/kyuden/banken/actions/workflows/ci.yml)
[![Gem Version](https://badge.fury.io/rb/banken.svg)](https://badge.fury.io/rb/banken)

Simple and lightweight authorization library for Rails inspired by Pundit.
Banken provides a set of helpers which restricts what resources
a given user is allowed to access.

Start with the tutorial:
 - [Tutorial](https://github.com/kyuden/banken/wiki/Tutorial)
 - [Tutorial (Japanese)](https://github.com/kyuden/banken/wiki/Tutorial-(japanese))

## What's the difference between Banken and Pundit?
 - [The difference between Banken and Pundit](https://github.com/kyuden/banken/wiki/The-difference-between-Banken-and-Pundit)
 - [The difference between Banken and Pundit (Japanese)](https://github.com/kyuden/banken/wiki/The-difference-between-Banken-and-Pundit-(Japanese))

## Installation

``` ruby
gem "banken"
```

Supported versions (tested in CI):

| Ruby | Rails |
|---|---|
| 3.3, 3.4, 4.0 | 7.1, 7.2, 8.0, 8.1 |

Ruby versions follow the official end-of-life schedule; Rails versions that
reached end-of-life are dropped gradually as applications move on. Environments
below these floors stay on banken 1.0.3, which works on Rails 7.1 and older.

Include `Banken::Authorization` in your application controller
(`ActionController::API` works too):

``` ruby
# app/controllers/application_controller.rb
class ApplicationController < ActionController::Base
  include Banken::Authorization
end
```

`include Banken` (the pre-1.1 form) still works and will be deprecated in 2.0.
Avoid it: it also brings every constant under the `Banken` namespace (`Error`,
`VERSION`, `LoyaltyFinder`, ...) into the controller's constant lookup, where it
shadows application constants of the same name.

Optionally, you can run the generator, which will set up an application loyalty
with some useful defaults for you:

``` sh
rails g banken:install
```

After generating your application loyalty, restart the Rails server so that Rails
can pick up any classes in the new `app/loyalties/` directory.

## Loyalties

Banken is focused around the notion of loyalty classes. We suggest that you put
these classes in `app/loyalties`. This is a simple example that allows updating
a post if the user is an admin, or if the post is unpublished:

``` ruby
# app/loyalties/posts_loyalty.rb
class PostsLoyalty
  attr_reader :user, :post

  def initialize(user, post)
    @user = user
    @post = post
  end

  def update?
    user.admin? || post.unpublished?
  end
end
```

As you can see, this is just a plain Ruby class. Banken makes the following
assumptions about this class:

- The class has the same name as some kind of controller class, only suffixed
  with the word "Loyalty".
- The first argument is a user. In your controller, Banken will call the
  `current_user` method to retrieve what to send into this argument
- The second argument is optional, whose authorization you want to check.
  This does not need to be an ActiveRecord or even an ActiveModel object,
  it can be anything really.
- The class implements some kind of query method, in this case `update?`.
  Usually, this will map to the name of a particular controller action.

That's it really.

Usually you'll want to inherit from the application loyalty created by the
generator, or set up your own base class to inherit from:

``` ruby
# app/loyalties/posts_loyalty.rb
class PostsLoyalty < ApplicationLoyalty
  def update?
    user.admin? || record.unpublished?
  end
end
```

In the generated `ApplicationLoyalty`, the optional object is called `record`.

Supposing that you are in PostsController, Banken now lets you do
this in your controller:

``` ruby
# app/controllers/posts_controller.rb
class PostsController < ApplicationController
  def update
    @post = Post.find(params[:id])
    authorize! @post
    if @post.update(post_params)
      redirect_to @post
    else
      render :edit, status: 422
    end
  end
end
```

The authorize method automatically infers from controller name that `Posts` will have a matching
`PostsLoyalty` class, and instantiates this class, handing in the current user
and the given optional object. It then infers from the action name, that it should call
`update?` on this instance of the loyalty. In this case, you can imagine that
`authorize!` would have done something like this:

``` ruby
raise "not authorized" unless PostsLoyalty.new(current_user, @post).update?
```

If there is no record to check, call `authorize!` without an argument (the
loyalty then receives `nil` as its record), or pass the class. For example:

Loyalty:
```ruby
# app/loyalties/posts_loyalty.rb
class PostsLoyalty < ApplicationLoyalty
  def admin_list?
    user.admin?
  end
end
```

Controller:
```ruby
# app/controllers/posts_controller.rb
class PostsController < ApplicationController
  def admin_list
    authorize!
    # Rest of controller action
  end
end
```

You can easily get a hold of an instance of the loyalty through the `loyalty`
method in both the view and controller. This is especially useful for
conditionally showing links or buttons in the view:

``` erb
<% if loyalty(@post, :posts).update? %>
  <%= link_to "Edit post", edit_post_path(@post) %>
<% end %>
```

Banken infers the loyalty from the controller path (`controller_path`) and the
query from the action name (`action_name`). A namespaced controller such as
`Admin::PostsController` (controller path `admin/posts`) therefore uses
`Admin::PostsLoyalty`, which lives in `app/loyalties/admin/posts_loyalty.rb`.
The same applies to controllers inside Rails engines: `Blorgh::PostsController`
uses `Blorgh::PostsLoyalty`. There is no fallback to a top-level loyalty.

To use another controller's loyalty, pass its controller path as the second
argument. Below calls `Admin::PostsLoyalty`:

``` erb
<% if loyalty(@post, 'admin/posts').update? %>
  <%= link_to "Edit post", edit_post_path(@post) %>
<% end %>
```

Banken also works for controllers dispatched without the router
(`PostsController.action(:index).call(env)`). In templates rendered through
`ActionController::Renderer` (`PostsController.render ...`), `loyalty` infers
the loyalty from the controller the renderer was called on; `authorize!` cannot
be used there because no action is running.

**Naming caveat:** `loyalty` is a public method on your controllers. Do not
define a controller action named `loyalty`, or it will shadow the helper. The
helper is scheduled to be renamed to `banken_loyalty` (with `loyalty` kept as an
alias) in 2.0.

## Using loyalties outside controllers

`Banken.loyalty!` builds a loyalty from a controller path, a user and a record,
for jobs, GraphQL resolvers or anywhere there is no controller:

``` ruby
Banken.loyalty!('admin/posts', user, post).update?
```

## Ensuring loyalties are used

Banken adds a method called `verify_authorized` to your controllers. This
method will raise an exception if `authorize!` has not yet been called. You
should run this method in an `after_action` to ensure that you haven't
forgotten to authorize the action. For example:

``` ruby
# app/controllers/application_controller.rb
class ApplicationController < ActionController::Base
  after_action :verify_authorized, except: :index
end
```


If you're using `verify_authorized` in your controllers but need to
conditionally bypass verification, you can use `skip_authorization`.
These are useful in circumstances where you don't want to disable verification for the
entire action, but have some cases where you intend to not authorize.

```ruby
# app/controllers/posts_controller.rb
class PostsController < ApplicationController
  def show
    record = Record.find_by(attribute: "value")
    if record.present?
      authorize! record
    else
      skip_authorization
    end
  end
end
```

If you need to perform some more sophisticated logic or you want to raise a custom
exception you can use the lower-level method `banken_authorization_performed?`, which
returns `true` or `false` depending on whether `authorize!` (or `skip_authorization`) has been called.

## Just plain old Ruby

As you can see, Banken doesn't do anything you couldn't have easily done
yourself.  It's a very small library, it just provides a few neat helpers.
Together these give you the power of building a well structured, fully working
authorization system without using any special DSLs or funky syntax or
anything.

Remember that all of the loyalty is just plain Ruby classes,
which means you can use the same mechanisms you always use to DRY things up.
Encapsulate a set of permissions into a module and include them in multiple
loyalties. Use `alias_method` to make some permissions behave the same as
others. Inherit from a base set of permissions. Use metaprogramming if you
really have to.

## Generator

Use the supplied generator to generate loyalties:

``` sh
rails g banken:loyalty posts
```

## Closed systems

In many applications, only logged in users are really able to do anything. If
you're building such a system, it can be kind of cumbersome to check that the
user in a loyalty isn't `nil` for every single permission.

We suggest that you define a filter that redirects unauthenticated users to the
login page. As a secondary defence, if you've defined an ApplicationLoyalty, it
might be a good idea to raise an exception if somehow an unauthenticated user
got through. This way you can fail more gracefully.

``` ruby
# app/loyalties/application_loyalty.rb
class ApplicationLoyalty
  def initialize(user, record)
    raise Banken::NotAuthorizedError, "must be logged in" unless user
    @user = user
    @record = record
  end
end
```

## Rescuing a denied Authorization in Rails

Banken raises a `Banken::NotAuthorizedError` you can
[rescue_from](https://guides.rubyonrails.org/action_controller_overview.html#rescue-from)
in your `ApplicationController`. You can customize the `user_not_authorized`
method in every controller.

```ruby
# app/controllers/application_controller.rb
class ApplicationController < ActionController::Base
  include Banken::Authorization

  rescue_from Banken::NotAuthorizedError, with: :user_not_authorized

  private

  def user_not_authorized
    flash[:alert] = "You are not authorized to perform this action."
    redirect_back_or_to(root_path, allow_other_host: false)
  end
end
```

Do not redirect to `request.referrer`: the `Referer` header is controlled by
the client. Depending on your open-redirect configuration that either sends the
user to another site or raises `ActionController::Redirecting::UnsafeRedirectError`.
`redirect_back_or_to` falls back to `root_path` when there is no referrer, and
`allow_other_host: false` makes it fall back for off-site referrers too,
whatever `raise_on_open_redirects` / `action_on_open_redirect` are set to.

If you only need the status code, map the error to 403 and let Rails render it:

```ruby
# config/application.rb
config.action_dispatch.rescue_responses["Banken::NotAuthorizedError"] = :forbidden
```

Without either, an unrescued `NotAuthorizedError` is a 500.

## Creating custom error messages

`NotAuthorizedError`s provide information on what query (e.g. `"create?"`), what
controller (the controller path, e.g. `"posts"` or `"admin/posts"`), and what
loyalty (e.g. an instance of `PostsLoyalty`) caused the error to be raised. The
default message names only these, never the user or the record.

One way to use these `query`, `controller`, and `loyalty` properties is to connect
them with `I18n` to generate error messages. Here's how you might go about doing
that.

```ruby
# app/controllers/application_controller.rb
class ApplicationController < ActionController::Base
  rescue_from Banken::NotAuthorizedError, with: :user_not_authorized

  private

  def user_not_authorized(exception)
    loyalty_name = exception.loyalty.class.to_s.underscore

    flash[:error] = t "#{loyalty_name}.#{exception.query}", scope: "banken", default: :default
    redirect_back_or_to(root_path, allow_other_host: false)
  end
end
```

```yaml
en:
  banken:
    default: 'You cannot perform this action.'
    posts_loyalty:
      update?: 'You cannot edit this post!'
      create?: 'You cannot create posts!'
```

Of course, this is just an example. Banken is agnostic as to how you implement
your error messaging.

## Customize Banken user

In some cases your controller might not have access to `current_user`, or your
`current_user` is not the method that should be invoked by Banken. Simply
define a method in your controller called `banken_user` (under `private`, so it
does not become a routable action):

```ruby
class ApplicationController < ActionController::Base
  include Banken::Authorization

  private
    def banken_user
      User.find_by_other_means
    end
end
```

## Deprecation warnings

Banken reports its own deprecations through `Banken.deprecator`, an
`ActiveSupport::Deprecation` instance. When banken is loaded by Bundler in the
usual way (after `require "rails/all"`), `Banken::Railtie` registers it with
`Rails.application.deprecators`, so `config.active_support.deprecation` and
`config.active_support.report_deprecations` apply to Banken as well. If you
require banken only after Rails has initialized, register it yourself:

```ruby
Rails.application.deprecators[:banken] = Banken.deprecator
```

## Additional context

Banken strongly encourages you to model your application in such a way that the
only context you need for authorization is a user object and a domain model that
you want to check authorization for. If you find yourself needing more context than
that, consider whether you are authorizing the right domain model, maybe another
domain model (or a wrapper around multiple domain models) can provide the context
you need.

Banken does not allow you to pass additional arguments to loyalties for precisely
this reason.

However, in very rare cases, you might need to authorize based on more context than just
the currently authenticated user. Suppose for example that authorization is dependent
on IP address in addition to the authenticated user. In that case, one option is to
create a special class which wraps up both user and IP and passes it to the loyalty.

``` ruby
class UserContext
  attr_reader :user, :ip

  def initialize(user, ip)
    @user = user
    @ip = ip
  end
end

# app/controllers/application_controller.rb
class ApplicationController < ActionController::Base
  include Banken::Authorization

  private
    def banken_user
      UserContext.new(current_user, request.ip)
    end
end
```

## Strong parameters

Mass-assignment protection is handled in the controller with strong
parameters. With Banken you can control which attributes a user has access to
update via your loyalties. You can set up a `permitted_attributes` method in
your loyalty like this:

```ruby
# app/loyalties/posts_loyalty.rb
class PostsLoyalty < ApplicationLoyalty
  def permitted_attributes
    if user.admin? || user.owner_of?(record)
      [:title, :body, :tag_list]
    else
      [:tag_list]
    end
  end
end
```

You can now retrieve these attributes from the loyalty:

```ruby
# app/controllers/posts_controller.rb
class PostsController < ApplicationController
  def update
    @post = Post.find(params[:id])
    if @post.update(post_params)
      redirect_to @post
    else
      render :edit, status: 422
    end
  end

  private

  def post_params
    params.require(:post).permit(loyalty(@post).permitted_attributes)
  end
end
```

However, this is a bit cumbersome, so Banken provides a convenient helper method.
The record may be an instance or a class (`permitted_attributes(Post)` on create):

```ruby
# app/controllers/posts_controller.rb
class PostsController < ApplicationController
  def update
    @post = Post.find(params[:id])
    if @post.update(permitted_attributes(@post))
      redirect_to @post
    else
      render :edit, status: 422
    end
  end
end
```

Attributes that the loyalty does not list are dropped like any other
unpermitted parameter. With `config.action_controller.action_on_unpermitted_parameters = :raise`
they raise `ActionController::UnpermittedParameters`, which Rails reports as a 500
unless you map it in `rescue_responses`.

`permitted_attributes` reads `params[<key>]`, where the key is the demodulized,
underscored class name (`Post` and `Admin::Post` both give `post`). To change
that, override one of these hooks in your controller. **Define the override
under `private` (or `protected`)**: a public method on a controller is a
routable action.

```ruby
class ApplicationController < ActionController::Base
  include Banken::Authorization

  private
    # Use the key Rails forms generate (Admin::Post -> "admin_post");
    # model_name works on ActiveModel classes and instances alike
    def banken_param_key(record)
      record.respond_to?(:model_name) ? record.model_name.param_key : super
    end

    # Or take the attributes from somewhere else entirely
    def banken_params_for(record)
      params.require(:payload)
    end
end
```

## License

Licensed under the MIT license, see the separate LICENSE.txt file.
