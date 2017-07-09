class ApplicationController
  include Banken

  attr_accessor :current_user, :params

  def initialize(current_user, params={})
    @current_user = current_user
    @params = params
  end

  class << self
    def controller_path
      name.sub(/Controller$/, '').underscore
    end
  end
end
