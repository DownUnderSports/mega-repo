require 'rails_helper'

RSpec.describe InfokitPolicy do
  let(:user) { User.new(category: Athlete.new) }

  subject { described_class }

  permissions :valid? do
    it "allows access if record has not already requested infokit" do
      expect(subject).to permit(user, user)
    end

    it "denies access if record does not exist" do
      expect(subject).to_not permit(user, nil)
    end

    it "denies access if record has already requested infokit" do
      allow(user).to receive(:requested_infokit?).and_return(true)
      expect(subject).to_not permit(user, user)

      allow(user).to receive(:requested_infokit?).and_return(false)
      expect(subject).to permit(user, user)
    end

    it "denies access if record is not an athlete" do
      allow(user).to receive(:is_athlete?).and_return(false)
      expect(subject).to_not permit(user, user)

      allow(user).to receive(:is_athlete?).and_return(true)
      expect(subject).to permit(user, user)
    end

  end

  permissions :create? do
    it "denies access if record has already requested infokit" do
      allow(user).to receive(:requested_infokit?).and_return(true)
      expect(subject).to_not permit(user, user)

      allow(user).to receive(:requested_infokit?).and_return(false)
      expect(subject).to permit(user, user)
    end

    it "denies access if record is not an athlete" do
      allow(user).to receive(:is_athlete?).and_return(false)
      expect(subject).to_not permit(user, user)

      allow(user).to receive(:is_athlete?).and_return(true)
      expect(subject).to permit(user, user)
    end

    it "allows access if it's a new record" do
      expect(subject).to permit(user, nil)
    end

    it "allows access if record has not already requested infokit" do
      expect(subject).to permit(user, user)
    end
  end
end
