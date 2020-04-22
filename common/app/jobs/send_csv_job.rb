class SendCSVJob < ApplicationJob
  queue_as :default

  def perform(user_id, view, file_name, subject = 'Here is your File', message = 'System Generated CSV', params = {}, env = nil)
    user = (user = User.get(user_id))&.is_dus_staff? ? user : nil

    object_path = "tmp/csvs/#{rand}-#{Time.zone.now.to_i}.csv"

    object = s3_bucket.object(object_path)

    begin
      object.
        upload_stream(tempfile: true) do |write_stream|
          renderer = case env
          when Hash
            ApplicationController.renderer.new(env)
          when String
            env.classify.constantize
          else
            ApplicationController
          end

          write_stream << renderer.render(
            template: view,
            layout: false,
            assigns: { current_user: user, **params.symbolize_keys }
          )
        end

        FileMailer.
          with(
            object_path: object_path,
            compress: true,
            file_name: "#{file_name.to_s.sub(/\.csv(\.csvrb)?$/, '')}#{params[:with_time] == false ? '' : "_#{Time.now.strftime('%Y-%m-%d_%H-%M-%S')}"}.csv",
            email: user&.email&.presence || 'it@downundersports.com',
            subject: subject,
            message: message,
            delete_file: true
          ).
          send_s3_file.
          deliver_later(queue: :staff_mailer)
    rescue Exception
      object.delete
      raise
    end
  end
end
