class ErrorMailer < ImportantMailer
  layout 'error_mailer'

  # default use_account: :error

  def invalid_infokit_request
    @values = values
    @user = User.get(params[:user_id].presence || values[:id].presence || test_user.id)

    mail to: 'it@downundersports.com', subject: "Failed Infokit Request for #{@user.dus_id} - #{params[:server_time].presence || Time.zone.now.to_s}" do |format|
      format.html(content_transfer_encoding: 'quoted-printable')
    end
  end

  def log_error
    @errors = values.to_a.sort.to_h.except(:logHistory, 'logHistory')
    @console = values[:logHistory]

    mail subject: "Client Error occurred in office app - #{params[:server_time].presence || Time.zone.now.to_s}", to: 'it@downundersports.com' do |format|
      format.html(content_transfer_encoding: 'quoted-printable')
    end
  end

  def load_error
    @page = values[:page] || ''
    @user_agent = values[:agent] || ''
    @console = values[:console] || {}
    @navigator = values[:navigator] || {}
    @waited = values[:waited]
    @loading_completed = !!values[:loading_completed]

    mail subject: "#{@loading_completed ? 'Client Failed to Load' : 'Client Gave Up On'} '#{@page}' After #{@waited}s - #{params[:server_time].presence || Time.zone.now.to_s}", to: 'it@downundersports.com' do |format|
      format.html(content_transfer_encoding: 'quoted-printable')
    end
  end

  def ruby_error
    @message = values[:message],
    @stack = values[:stack] || [],
    @additional = values[:additional] || []

    mail subject: "Ruby Error occurred in office app - #{params[:server_time].presence || Time.zone.now.to_s}", to: 'it@downundersports.com' do |format|
      format.html(content_transfer_encoding: 'quoted-printable')
    end
  end

  private
    def values
      @param_values ||= (params.presence || {}).except(:server_time, 'server_time')
    end
end
