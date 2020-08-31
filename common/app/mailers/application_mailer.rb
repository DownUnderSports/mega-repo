# encoding: utf-8
# frozen_string_literal: true

class ApplicationMailer < ActionMailer::Base
  prepend_view_path Rails.root.join('vendor', 'common', 'app', 'views')

  helper ViewAndControllerMethods

  # after_action do
  #   sleep 8 unless Boolean.parse(@async)
  # end

  default from: "Down Under Sports <no-reply@downundersports.com>",
          content_transfer_encoding: "quoted-printable"

  layout 'mailer'

  def self.filter_emails(emails, all: false)
    all = all ? true : [ false, true, nil ]
    emails = [emails].flatten.map {|email| email.to_s.split(';').map {|e| e.strip.downcase}}
    emails = emails.flatten.uniq.select(&:present?)
    emails - Unsubscriber.where(category: 'E', value: emails, all: all).pluck(:value)
  end

  def get_full_path_to_asset(filename)
    manifest_file = Rails.application.assets_manifest.assets[filename]
    if manifest_file
      File.join(Rails.application.assets_manifest.directory, manifest_file)
    else
      Rails.application.assets&.[](filename)&.filename
    end
  end

  def mail(email: nil, skip_filter: false, include_gayle: false, **params)
    headers['List-Unsubscribe'] = '<mailto:unsubscribe@downundersports.com>'
    params.reverse_merge!(apply_defaults({}).slice(:use_account))

    @include_gayle = Boolean.parse(include_gayle)

    use_account = params.delete(:use_account).presence
    mail_name = params.delete(:mail_name).presence || caller_locations(1,1)[0].label
    params[:to] = email if email

    has_email = false

    [:to, :cc, :bcc].each do |h|
      if params[h].present?
        params[h] = skip_filter ? production_email(params[h]) : filter_emails(params[h], all: true).presence
        has_email ||= params[h].present?
      end
    end

    params[:to] = production_email('no-email-available@downundersports.com') unless has_email

    if use_account &&= Rails.application.credentials.dig(:mailer, use_account, :from).presence
      # params[:delivery_method_options] = {
      #   :address        => 'smtp.gmail.com',
      #   :port           => '587',
      #   :authentication => :plain,
      #   :user_name      => Rails.application.credentials.dig(:mailer, use_account, :username),
      #   :password       => Rails.application.credentials.dig(:mailer, use_account, :password),
      #   :domain         => 'downundersports.com',
      #   :enable_starttls_auto => true
      # }

      params[:from] = use_account
    end

    params[:reply_to] = "sampson@downundersports.com" if @include_gayle && Rails.env.development?

    m = super(
      **params
    ) do |format|
      if block_given?
        yield format
      else
        format.text
        format.html(content_transfer_encoding: 'quoted-printable')
      end
    end
    m.content_transfer_encoding = 'quoted-printable'
    m.after_send do
      SentMail.create(name: mail_name)
    end
    m
  end

  def money_email
    @money_email ||= production_email('money@downundersports.com')
  end

  def it_email
    @it_email ||= production_email('it@downundersports.com')
  end

  def production_email(email = nil)
    if Rails.env.development?
      result = %w[ sampson@downundersports.com ]
      result << "gayle@downundersports.com" if @include_gayle && email_has_gayle(email)
    elsif block_given?
      result = yield
    else
      result = email
    end

    result
  end

  def filter_emails(emails, all: false)
    production_email do
      self.class.filter_emails(emails, all: all)
    end
  end

  def get_view
    av = ActionView::Base.new()
    av.view_paths = ActionController::Base.view_paths

    av.class_eval do
      include Rails.application.routes.url_helpers
      # include ApplicationHelper
    end
    av
  end

  def email_has_gayle(email = nil)
    !!email && (
      [ email ].flatten.any? {|e| e.to_s.split(";").include? "gayle@downundersports.com" }
    )
  end
end
