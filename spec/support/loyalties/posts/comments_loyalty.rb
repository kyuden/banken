require_relative '../application_loyalty'

module Posts
  class CommentsLoyalty < ApplicationLoyalty
    def update?
      record.post.user == user
    end

    def show?
      true
    end

    def permitted_attributes
      if record.post.user == user
        [:body, :published]
      else
        [:body]
      end
    end
  end
end
