require "spec_helper"

describe Banken::LoyaltyFinder do
  let(:loyalty_finder) { Banken::LoyaltyFinder.new(controller_name) }

  describe "#loyalty" do
    context "when :posts is given as a controller_name" do
      let(:controller_name) { :posts }
      it "returns PostsLoyalty" do
        expect(loyalty_finder.loyalty).to eq PostsLoyalty
      end
    end

    context "when :posty(=typo) is given as a controller_name" do
      let(:controller_name) { :posty }
      it "returns nil" do
        expect(loyalty_finder.loyalty).to eq nil
      end
    end

    context "when 'admin/post' is given as a controller_name" do
      let(:controller_name) { "admin/posts" }
      it "returns Admin::PostsLoyalty" do
        expect(loyalty_finder.loyalty).to eq Admin::PostsLoyalty
      end
    end
  end

  describe "#loyalty!" do
    context "when :posts is given as a controller_name" do
      let(:controller_name) { :posts }
      it "returns PostsLoyalty" do
        expect(loyalty_finder.loyalty).to eq PostsLoyalty
      end
    end

    context "when :posty(=typo) is given as a controller_name" do
      let(:controller_name) { :posty }
      it "returns PostsLoyalty" do
        expect{
          loyalty_finder.loyalty!
        }.to raise_error(Banken::NotDefinedError)
      end
    end
  end
end