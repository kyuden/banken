class Post < Struct.new(:user, :id)
  def self.published
    :published
  end
end
