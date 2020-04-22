require 'rails_helper'

RSpec.describe API::StatesController, type: :controller do
  describe "GET #index" do
    let!(:state) { create(:state) }
    before(:each) do
      get :index, format: :json
    end

    it "returns http success" do
      expect(response).to be_successful
    end

    it "returns all states" do
      val = JSON.parse(response.body)
      expect(val.size).to eq(State.count)
      expect(State.count).to_not eq(0)
    end
  end
end
