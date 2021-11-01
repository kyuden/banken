class Post < Struct.new(:user, :id)
  def self.published
    :published
  end
  def to_s; "Post"; end
  def inspect; "#<Post>"; end

  class Comment < Struct.new(:post, :body, :published)
    def to_s; "Post::Comment"; end
    def inspect; "#<Post::Comment>"; end
    def model_name
      Struct.new(:param_key).new('post_comment')
    end
  end
end
