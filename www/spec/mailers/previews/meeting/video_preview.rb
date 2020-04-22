# Preview all emails at http://localhost:3000/rails/mailers/meeting/video
class Meeting::VideoPreview < ActionMailer::Preview
  def information
    base_params.information
  end

  def information_watched
    base_params.information_watched
  end

  def fundraising
    base_params.fundraising
  end

  private
    def base_params
      Meeting::VideoMailer.
        with(video_id: Meeting::Video.where(category: 'I').last&.id || 1, user_id: test_user.id)
    end
end
