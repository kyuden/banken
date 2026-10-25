# Loaded on demand through Object.autoload by LoyaltyFinderTest. The class body
# raises NoMethodError, like a typo in a class-level macro would.
class BuggyPostsLoyalty < ApplicationLoyalty
  permit_everything_for :admin
end
