module Posts
  class CommentsController
    include Banken

    attr_accessor :current_user, :params

    def initialize(current_user, params={})
      @current_user = current_user
      @params = params
    end
  end
end
