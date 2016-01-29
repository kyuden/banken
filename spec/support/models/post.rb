class Post < Struct.new(:user, :id)
  def self.published
    :published
  end
  def to_s; "Post"; end
  def inspect; "#<Post>"; end
end
