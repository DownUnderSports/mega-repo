# encoding: utf-8
# frozen_string_literal: true

module Admin
  class FundraisingIdeasController < ::Admin::ApplicationController
    def index
      respond_to do |format|
        format.html { fallback_index_html }
        format.any do
          fundraising_ideas = FundraisingIdea.ordered

          if Rails.env.development? || stale?(fundraising_ideas)
            return render json: {
              fundraising_ideas: (
                fundraising_ideas.map do |idea|
                  {
                    id: idea.id,
                    title: idea.title,
                    description: idea.description,
                    display_order: idea.display_order,
                    image_count: idea.images.size
                  }
                end
              )
            }
          end
        end
      end
    end

    def show
      respond_to do |format|
        format.html { fallback_index_html }
        format.any do
          idea = authorize FundraisingIdea.find_by(id: params[:id])
          if Boolean.parse(params[:force].presence) || stale?(idea)
            return render json: idea_json(idea)
          end
        end
      end
    end

    def update
      idea = authorize FundraisingIdea.find_by(id: params[:id])
      if idea
        idea.assign_attributes(whitelisted_idea_params)
        save_idea(idea)
      else
        return render json: { errors: ["Idea Not Found"] }, status: 422
      end
    end

    def create
      idea = authorize FundraisingIdea.new(whitelisted_idea_params)
      save_idea(idea)
    end

    rescue_from(ActionController::ParameterMissing) do |parameter_missing_exception|
      render json: {
        errors: [
          "Required parameter missing: #{parameter_missing_exception.param}"
        ]
      }, :status => :bad_request
    end

    private
      def idea_json(idea, skip_images: false)
        {
          id: idea.id,
          title: idea.title,
          description: idea.description,
          display_order: idea.display_order,
          images: skip_images ? nil : (
            idea.images.ordered.map do |image|
              {
                id: image.id,
                alt: image.alt,
                display_order: image.display_order,
                hide: !!image.hide,
              }.merge(
                image.attached? ? {
                  small: url_for(image.variant(resize: '640x360>')),
                  medium: url_for(image.variant(resize: '1280x720>')),
                  large: url_for(image.variant(resize: '1920x1080>')),
                  src: url_for(image.variant(resize: '1024x576>')),
                } : {}
              )
            end
          )
        }
      end

      def save_idea(idea)
        if idea.save
          return render json: idea_json(idea, skip_images: true)
        else
          return render json: { errors: idea.errors.full_messages }, status: 422
        end
      end

      def whitelisted_idea_params
        base =
          begin
            params.require(:fundraising_idea)
          rescue ActionController::ParameterMissing
            params.require(:idea)
          end

          base ? base.permit(:title, :description, :display_order) : {}
      end
  end
end
