require "rails_helper"

RSpec.describe API::SportsController, type: :routing do
  describe "routing" do

    it "routes to #index" do
      expect(:get => "/api/sports").to route_to("api/sports#index")
    end


    it "routes to #show" do
      expect(:get => "/api/sports/1").to route_to("api/sports#show", :id => "1")
      expect(:get => "/api/sports/gf").to route_to("api/sports#show", :id => "gf")
    end
  end
end
