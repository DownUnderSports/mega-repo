# encoding: utf-8
# frozen_string_literal: true

require_dependency 'user/views'

class User < ApplicationRecord
  module Views
    class IndexPolicy < UserPolicy
    end
  end
end
