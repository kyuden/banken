require_relative '../application_loyalty'

module Admin
  class PostsLoyalty < ApplicationLoyalty
    def index?
      true
    end

    def permitted_attributes
      [:title]
    end
  end
end
