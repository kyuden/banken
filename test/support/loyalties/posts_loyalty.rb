require_relative 'application_loyalty'

class PostsLoyalty < ApplicationLoyalty
  def update?
    record.user == user
  end

  def destroy?
    false
  end

  def show?
    true
  end

  # Returns nil rather than false: authorize! must still deny.
  def archive?
    nil
  end

  # Returns a truthy non-boolean: authorize! must allow.
  def publish?
    :yes
  end

  # The record may be a class (permitted_attributes(Post) on create).
  def permitted_attributes
    if record.is_a?(Post) && record.user == user
      [:title, :votes]
    else
      [:votes]
    end
  end
end
