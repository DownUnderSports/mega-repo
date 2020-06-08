require 'rails_helper'

RSpec.describe "API::Tasks", type: :request do
  before(:example) do
    create(:task)
  end

  describe "GET /api/tasks" do
    let(:result) do
      get api_tasks_path
      response
    end

    it "responds to requests with json" do
      expect(result.content_type).to eq('application/json')
    end

    it "returns an ok status" do
      expect(result).to have_http_status(:ok)
    end

    it "returns all tasks" do
      expect(JSON.parse(result.body).size).to eq(Task.count)
    end
  end

  describe "POST /api/tasks" do
    let(:new_task) do
      build(:task)
    end
    let(:valid_result) do
      post api_tasks_path, params: { task: new_task.attributes }
      response
    end

    let(:empty_result) do
      post api_tasks_path, params: { task: {} }
      response
    end

    let(:invalid_result) do
      post api_tasks_path, params: { task: { first: 'a' } }
      response
    end

    it "responds to requests with json" do
      expect(valid_result.content_type).to eq('application/json')
    end

    context :valid_request do
      it "returns a created status" do
        expect(valid_result).to have_http_status(:created)
      end

      it "returns the created task" do
        expect(JSON.parse(valid_result.body)['id']).to eq(Task.order(:created_at).last.id)
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
        expect(body['title']).to_not be_empty
        expect(body['title'].first).to eq("can't be blank")
      end
    end
  end
end
