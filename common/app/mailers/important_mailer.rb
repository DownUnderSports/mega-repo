# encoding: utf-8
# frozen_string_literal: true

class ImportantMailer < ApplicationMailer
  def mail(**params)
    params[:skip_filter] = true
    if block_given?
      super(**params) do |format|
        yield format
      end
    else
      super(**params)
    end
  end
end
