require "spec_helper"

describe Banken do
  let(:user) { double }
  let(:post) { Post.new(user, 1) }
  let(:post2) { Post.new(user, 2) }
  let(:comment) { Comment.new }
  let(:article) { Article.new }
  let(:posts_controller) { PostsController.new(user, { :action => 'update', :controller => 'posts' }) }
  let(:users_controller) { UsersController.new(user, { :action => 'index', :controller => 'users' }) }

  describe ".loyalty!" do
    it "returns an instantiated loyalty given a controller name" do
      loyalty = Banken.loyalty!('posts', user, post)
      expect(loyalty.user).to eq user
      expect(loyalty.record).to eq post
      expect(loyalty.class.name).to eq 'PostsLoyalty'
    end

    it "returns an instantiated loyalty given a controller name of symbol" do
      loyalty = Banken.loyalty!(:posts, user, post)
      expect(loyalty.user).to eq user
      expect(loyalty.record).to eq post
      expect(loyalty.class.name).to eq 'PostsLoyalty'
    end

    it "returns an instantiated loyalty given record is nil" do
      loyalty = Banken.loyalty!(:posts, user)
      expect(loyalty.user).to eq user
      expect(loyalty.record).to eq nil
      expect(loyalty.class.name).to eq 'PostsLoyalty'
    end

    it "throws an exception if the given loyalty can't be found" do
      expect { Banken.loyalty!('articles', user, article) }.to raise_error(Banken::NotDefinedError)
    end
  end

  describe ".def_banken_query_method_for" do
    it "defines banken query method to the loyalty class with the same name as the Controller" do
      UsersController.def_banken_query_method_for(:index) { true }
      loyalty = Banken.loyalty!('users', user)
      expect(loyalty.class.name).to eq 'UsersLoyalty'
      expect(loyalty.class.superclass.name).to eq 'ApplicationLoyalty'
      expect(users_controller.authorize!).to be true
    end
  end

  describe "#verify_authorized" do
    it "does nothing when authorized" do
      posts_controller.authorize!(post)
      posts_controller.verify_authorized
    end

    it "raises an exception when not authorized" do
      expect { posts_controller.verify_authorized }.to raise_error(Banken::AuthorizationNotPerformedError)
    end
  end

  describe "#banken_loyalty_authorized?" do
    it "is true when authorized!" do
      posts_controller.authorize!(post)
      expect(posts_controller.banken_loyalty_authorized?).to be true
    end

    it "is false when not authorized!" do
      expect(posts_controller.banken_loyalty_authorized?).to be false
    end
  end

  describe "#skip_authorization" do
    it "disables authorization verification" do
      posts_controller.skip_authorization
      expect { posts_controller.verify_authorized }.not_to raise_error
    end
  end

  describe "#authorize!" do
    context 'with action returning true' do
      it "infers the loyalty name and authorizes based on it" do
        expect(posts_controller.authorize!(post)).to be true
      end
    end

    context 'with action returning false' do
      before { posts_controller.params[:action] = 'destroy' }

      it "throws an exception of Banken::NotAuthorizedError" do
        expect { posts_controller.authorize!(post) }.to raise_error(Banken::NotAuthorizedError)
      end
    end

    context 'with nothing loyalty' do
      before { posts_controller.params[:controller] = 'articles' }

      it "throws an exception of Banken::NotDefinedError" do
        expect { posts_controller.authorize!(article) }.to raise_error(Banken::NotDefinedError)
      end
    end

    context 'with nothing action in loyalty' do
      before { posts_controller.params[:action] = 'update_all' }

      it "throws an exception of NoMethodError" do
        expect { posts_controller.authorize!(post) }.to raise_error(NoMethodError)
      end
    end
  end

  describe "#banken_user" do
    it 'returns the same thing as current_user' do
      expect(posts_controller.banken_user).to eq posts_controller.current_user
    end
  end

  describe "#loyalty" do
    it "returns an instantiated loyalty" do
      loyalty = posts_controller.loyalty(post, 'posts')
      expect(loyalty.user).to eq user
      expect(loyalty.record).to eq post
    end

    it "returns an different loyalty each record" do
      loyalty = posts_controller.loyalty(post, 'posts')
      loyalty2 = posts_controller.loyalty(post2, 'posts')

      expect(loyalty).not_to eq loyalty2
    end


    it "throws an exception if the given loyalty can't be found" do
      expect { posts_controller.loyalty('articles', article) }.to raise_error(Banken::NotDefinedError)
    end
  end

  describe "#permitted_attributes" do
    it "checks loyalty for permitted attributes" do
      params = ActionController::Parameters.new({ controller: 'posts', action: 'update', post: { title: 'Hello', votes: 5, admin: true } })

      expect(PostsController.new(user, params).permitted_attributes(post)).to eq({ 'title' => 'Hello', 'votes' => 5 })
      expect(PostsController.new(double, params).permitted_attributes(post)).to eq({ 'votes' => 5 })
    end
  end

  describe "Banken::NotAuthorizedError" do
    it "can be initialized with a string as message" do
      error = Banken::NotAuthorizedError.new("must be logged in")
      expect(error.message).to eq "must be logged in"
    end
  end
end
