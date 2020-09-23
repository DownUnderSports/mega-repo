# encoding: utf-8
# frozen_string_literal: true

module Admin
  class AvatarsController < ::Admin::ApplicationController
    # == Modules ============================================================

    # == Class Methods ======================================================

    # == Pre/Post Flight Checks =============================================
    before_action :lookup_user, except: [ :index ]

    # == Actions ============================================================
    def show
      redirect_to @found_user.avatar, status: 303
    end

    def update
      authorize ActiveStorage::Attachment
      # existing = [ @found_user.avatar&.attachment&.blob, @found_user.last_avatar&.attachment&.blob ]
      # # blob = ActiveStorage::Blob.find_signed(params[:user][:avatar])
      # # @found_user.avatar.attach(io: open(blob.variant({resize: '1000x1000>'}).processed.service_url.sub('localhost:3000', "lvh.me:#{local_port}")), filename: blob.filename, content_type: blob.content_type)
      @found_user.update!(params.require(:user).permit(:avatar))
      # existing.each do |blob|
      #   begin
      #     ActiveStorage::Blob.find_by(id: blob.id)&.purge_later
      #   rescue
      #     p 'blob purge error'
      #   end
      # end
      return render json: { avatar: url_for(@found_user.reload.avatar.variant(resize: '500x500>')) }, status: 200
    rescue
      puts msg = $!.message
      puts $!.backtrace

      return not_authorized [ 'Failed to add Sponsor Photo', msg ], 422
    end
    # == Cleanup ============================================================

    # == Utilities ==========================================================

  end
end
