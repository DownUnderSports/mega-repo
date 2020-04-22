# encoding: utf-8
# frozen_string_literal: true

module Followable
  extend ActiveSupport::Concern

  module ClassMethods
    def follower
      begin
        self::Follower
      rescue NameError
        self.const_set "Follower", Class.new(self)
        self::Follower.table_name = self.table_name

        begin
          self::Follower.establish_connection "follower_#{Rails.env}".to_sym
        rescue
          self::Follower.establish_connection Rails.env.to_sym
        end
        self::Follower
      end
    end
  end

end
