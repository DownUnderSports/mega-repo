# encoding: utf-8
# frozen_string_literal: true

module Admin
  class FundraisingIdeasController < ::Admin::ApplicationController
    def index
      fundraising_ideas = FundraisingIdea.ordered

      if stale? fundraising_ideas
        return render json: {
          fundraising_ideas: (
            fundraising_ideas.map do |idea|
              {
                id: idea.id,
                title: idea.title,
                description: idea.description,
                display_order: idea.display_order
                image_count: idea.images.size
              }
            end
          )
        }
      end
    end

    def show
      idea = authorize FundraisingIdea.find_by(id: params[:id])
      if stale? idea
        return render json: idea_json(idea)
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

    private
      def idea_json(idea, skip_images: false)
        {
          id: idea.id,
          title: idea.title,
          description: idea.description,
          display_order: idea.display_order
          images: skip_images ? [] : (
            idea.images.ordered.with_attached_file.map do |image|
              {
                id: image.id,
                alt: image.alt,
                display_order: image.display_order,
                src: url_for(image.variant(resize: '1024x500>'))
              }
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
        params.
          require(:fundraising_idea).
          permit(
            :title,
            :description,
            :display_order,
          )
      end
  end
end
