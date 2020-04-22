# encoding: utf-8
# frozen_string_literal: true

require_dependency 'invite'

class GenerateQrCodesJob < ApplicationJob
  queue_as :importing

  def perform(**opts)
    QrCodeProcessor.run **(opts.merge(img_assets_path: opts[:img_assets_path].presence || QrCodeProcessor.tmp_asset_path, work_is_stopping: work_is_stopping_lambda))
  end
end
