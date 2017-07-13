require '<%= File.exists?('spec/rails_helper.rb') ? 'rails_helper' : 'spec_helper' %>'

RSpec.describe <%= class_name %>Loyalty do
  let(:user) { User.new }
  let(:record) { nil }
  let(:loyalty) { <%= class_name %>Loyalty.new(user, record) }

  describe '#index?' do
    subject { loyalty.index? }
    it { is_expected.to eq false }
  end

  describe '#show?' do
    subject { loyalty.show? }
    it { is_expected.to eq false }
  end

  describe '#create?' do
    subject { loyalty.create? }
    it { is_expected.to eq false }
  end

  describe '#update?' do
    subject { loyalty.update? }
    it { is_expected.to eq false }
  end

  describe '#destroy?' do
    subject { loyalty.destroy? }
    it { is_expected.to eq false }
  end
end
