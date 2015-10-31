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

  def permitted_attributes
    if record.user == user
      [:title, :votes]
    else
      [:votes]
    end
  end
end
