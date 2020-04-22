# encoding: utf-8
# frozen_string_literal: true

require_dependency 'meeting'

class Meeting < ApplicationRecord
  class ApplicationMailer < ::MarketingMailer
    # default use_account: :meeting,
    #         content_transfer_encoding: "quoted-printable"
    default content_transfer_encoding: "quoted-printable"
  end
end
