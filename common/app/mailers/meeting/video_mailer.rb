# encoding: utf-8
# frozen_string_literal: true

require_dependency 'meeting'

class Meeting < ApplicationRecord
  class VideoMailer < Meeting::ApplicationMailer

    def information
      @video = Meeting::Video.find(params[:video_id])

      @user = params[:user_id] ? User.get(params[:user_id]) : User.find_by(email: params[:email])
      begin
        @dus_id = @user.related_athlete.dus_id
        @deposit_link = "https://downundersports.com/deposit/#{@dus_id}"
        @faq_link = "https://DownUnderSports.com/frequently-asked-questions?dus_id=#{@dus_id}"
      rescue
        @dus_id = nil
        @deposit_link = "https://downundersports.com/deposit"
        @faq_link = "https://DownUnderSports.com/frequently-asked-questions"
      end

      m = mail(to: params[:email] || 'mail@downundersports.com', subject: 'Down Under Sports Information Video')

      if m && @user
        m.after_send do
          message = params[:message] || @user.video_views.find_by(video_id: @video.id).video_message
          @user.contact_histories.create(
            category: :email,
            message: message,
            staff_id: auto_worker.category_id
          ) unless params[:history_id].presence && User::History.find_by(id: params[:history_id])
        end
      end

      m
    end

    def information_watched
      @video = Meeting::Video.find(params[:video_id])

      @user = params[:user_id] ? User.get(params[:user_id]) : User.find_by(email: params[:email])
      begin
        @rel_ath = @user.related_athlete
        @dus_id = @rel_ath.dus_id
        @deposit_link = "https://downundersports.com/deposit/#{@dus_id}"
        @faq_link = "https://DownUnderSports.com/frequently-asked-questions?dus_id=#{@dus_id}"
      rescue
        @rel_ath = nil
        @dus_id = nil
        @deposit_link = "https://downundersports.com/deposit"
        @faq_link = "https://DownUnderSports.com/frequently-asked-questions"
      end

      @expiration_date =
        @rel_ath&.
          offers&.
          find_by(amount: 200_00, name: 'Instant Discount')&.
          expiration_date ||
        (Date.today + 3)


      m = mail(to: params[:email] || 'mail@downundersports.com', subject: 'Thanks for Watching')

      if m && @user
        m.after_send do
          message = params[:message] || @user.video_views.find_by(video_id: @video.id).video_watched_message
          @user.contact_histories.create(
            category: :email,
            message: message,
            staff_id: auto_worker.category_id
          ) unless params[:history_id].presence && User::History.find_by(id: params[:history_id])
        end
      end

      m
    end

    def fundraising
      @video = Meeting::Video.find(params[:video_id])

      @user = params[:user_id] ? User.get(params[:user_id]) : User.find_by(email: params[:email])
      begin
        @dus_id = @user.related_athlete.dus_id
        @deposit_link = "https://downundersports.com/deposit/#{@dus_id}"
        @faq_link = "https://DownUnderSports.com/frequently-asked-questions?dus_id=#{@dus_id}"
      rescue
        @dus_id = nil
        @deposit_link = "https://downundersports.com/deposit"
        @faq_link = "https://DownUnderSports.com/frequently-asked-questions"
      end

      m = mail(to: params[:email] || 'mail@downundersports.com', subject: 'Down Under Sports Fundraising Video')

      if m && @user
        m.after_send do
          message = params[:message] || @user.video_views.find_by(video_id: @video.id).video_message
          @user.contact_histories.create(
            category: :email,
            message: message,
            staff_id: auto_worker.category_id
          ) unless params[:history_id].presence && User::History.find_by(id: params[:history_id])
        end
      end

      m
    end
  end
end
