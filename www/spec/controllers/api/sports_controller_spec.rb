require 'rails_helper'

RSpec.describe API::SportsController, type: :controller do

  describe "GET #index" do
    let!(:sport) { create(:sport) }
    before(:each) do
      get :index, format: :json
    end
    it "returns http success" do
      expect(response).to be_successful
      expect(JSON.parse(response.body).size).to eq(Sport.count)
    end

    it "returns all sports with partial info" do
      val = JSON.parse(response.body)
      expect(val.size).to eq(Sport.count)
      expect(Sport.count).to_not eq(0)
      expect(val.first['info']).to be_nil
    end
  end

  describe "GET #show" do
    let!(:sport) { create(:sport) }
    let!(:sport_info) { create(:sport_info, sport: sport) }
    before(:each) do
      # p sport_info.sport == sport
      get :show, params: {id: sport.id}, format: :json
    end

    it "returns http success" do
      get :show, params: {id: sport.id}, format: :json
      expect(response).to be_successful
    end

    it "returns a sport" do
      get :show, params: {id: sport.id}, format: :json
      r_body = JSON.parse(response.body)
      sport.attributes.each do |k, v|
        expect(r_body[k]).to eq sport[k]
      end
    end

    it "includes sport info" do
      r_body = JSON.parse(response.body)
      expect(r_body["info"]).to_not be_empty
      expect(r_body["info"]["title"]).to eq(sport_info.title)
      expect(r_body["info"]["tournament"]).to eq(sport_info.tournament)
      expect(r_body["info"]["first_year"]).to eq(sport_info.first_year)
      expect(r_body["info"]["departing_dates"]).to eq(sport_info.departing_dates)
      expect(r_body["info"]["team_count"]).to eq(sport_info.team_count)
      expect(r_body["info"]["team_size"]).to eq(sport_info.team_size)
      expect(r_body["info"]["description"]).to eq(sport_info.description)
      expect(r_body["info"]["bullet_points_array"]).to eq(sport_info.bullet_points_array)
      expect(r_body["info"]["programs_array"]).to eq(sport_info.programs_array)
      expect(r_body["info"]["background_image"]).to eq(sport_info.background_image)
      expect(r_body["info"]["additional"]).to eq(sport_info.additional)
    end
  end

end
