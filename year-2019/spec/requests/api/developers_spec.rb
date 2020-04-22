require 'rails_helper'

RSpec.describe "API::Developers", type: :request do
  before(:example) do
    create(:developer)
  end

  describe "GET /api/developers" do
    let(:result) do
      get api_developers_path
      response
    end

    it "responds to requests with json" do
      expect(result.content_type).to eq('application/json')
    end

    it "returns an ok status" do
      expect(result).to have_http_status(:ok)
    end

    it "returns all developers" do
      expect(JSON.parse(result.body).size).to eq(Developer.count)
    end
  end

  describe "POST /api/developers" do
    let(:new_dev) do
      build(:developer)
    end
    let(:valid_result) do
      post api_developers_path, params: { developer: new_dev.attributes }
      response
    end

    let(:empty_result) do
      post api_developers_path, params: { developer: {} }
      response
    end

    let(:invalid_result) do
      post api_developers_path, params: { developer: { first: 'a' } }
      response
    end

    it "responds to requests with json" do
      expect(valid_result.content_type).to eq('application/json')
    end

    context :valid_request do
      it "returns a created status" do
        expect(valid_result).to have_http_status(:created)
      end

      it "returns the created developer" do
        expect(JSON.parse(valid_result.body)['id']).to eq(Developer.order(:created_at).last.id)
      end
    end

    context :empty_request do
      it "throws an invalid params error" do
        expect { empty_result }.to raise_error(ActionController::ParameterMissing)
      end
    end

    context :invalid_request do
      it "returns a created status" do
        expect(invalid_result).to have_http_status(:unprocessable_entity)
      end

      it "returns an error object" do
        body = JSON.parse(invalid_result.body)
        expect(body['id']).to be_nil
        expect(body['dob']).to_not be_empty
        expect(body['dob'].first).to eq("can't be blank")
      end
    end
  end
end
