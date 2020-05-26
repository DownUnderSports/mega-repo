# encoding: utf-8
# frozen_string_literal: true

module Admin
  module FundraisingIdeas
    class ImagesController < ::Admin::ApplicationController
      # == Modules ============================================================

      # == Class Methods ======================================================

      # == Pre/Post Flight Checks =============================================

      # == Actions ============================================================
      def index
        idea = get_idea
        if Rails.env.development? || stale?(idea.images)
          return render json: {
            can_delete: current_user&.staff&.admin?,
            images: idea.images.map do |image|
              unless image.file.attached?
                image.destroy if image.created_at < 24.hours.ago
                next
              end
              p image_json(image)
              image_json(image)
            end.select(&:present?)
          }
        end
      end

      def create
        idea = get_idea

        image = idea.images.create(whitelisted_image_params)

        unless image.persisted? && image.attached?
          image.destroy
          if image.valid?
            raise image.errors.full_messages.first
          else
            raise "Invalid File Type"
          end
        end

        return render json: {
          message: 'Image Uploaded',
          image: image_json(image)
        }, status: 200
      rescue Exception
        return render json: {
          errors: [ $!.message ]
        }, status: 500
      end

      def destroy
        idea = get_idea

        raise "Image Not Found" unless image = idea&.images&.find(params[:id])

        image.destroy

        return render json: { message: "Deleted Image for #{idea.title}" }, status: 200
      rescue
        puts $!.message
        puts $!.backtrace
        return render json: { errors: [ $!.message ] }, status: 422
      end

      # == Cleanup ============================================================

      # == Utilities ==========================================================
      private
        def get_idea(*args)
          idea =
            authorize(
              FundraisingIdea.find_by(id: params[:fundraising_idea_id]),
              *args
            )

          raise "Idea Not Found" unless idea

          idea
        end

        def image_json(image)
          {
            id: image.id,
            alt: image.alt,
            display_order: image.display_order,
            src: url_for(image.file.variant(resize: '1024x500>'))
          }
        end

        def whitelisted_image_params
          params.require(:image).permit(:file, :alt, :display_order)
        end


    end
  end
end
