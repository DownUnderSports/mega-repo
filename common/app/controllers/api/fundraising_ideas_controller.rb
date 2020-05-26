# encoding: utf-8
# frozen_string_literal: true

module API
  class FundraisingIdeasController < API::ApplicationController
    def version
      return head (last_update == params[:version]) ? 204 : 410
    end

    def index
      ideas = FundraisingIdea.ordered

      if stale? ideas
        return render json: {
          fundraising_ideas: (
            ideas.map do |idea|
              {
                id: idea.id,
                title: idea.title,
                description: idea.description,
                display_order: idea.display_order,
                images: (
                  idea.images.ordered.map do |image|
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
          ),
          version: last_update
        }
      end
    end

    private
      def last_update
        begin
          FundraisingIdea.
            order(updated_at: :desc).
            select(:updated_at).
            limit(1).
            pluck(:updated_at).
            first.utc.iso8601
        rescue
          puts $!.message
          puts $!.backtrace
          nil
        end
      end
  end
end
