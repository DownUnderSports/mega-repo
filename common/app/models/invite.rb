# encoding: utf-8
# frozen_string_literal: true

module Invite
  def self.table_name_prefix
    'invite_'
  end

  def self.headers
    Parser.headers
  end

  def self.csv_rows(params, &block)
    if block_given?
      Parser.csv_rows(params) {|r, id| block.call(r, id) }
    else
      Parser.csv_rows(params)
    end
  end

  def self.invitable_headers
    Lister.headers
  end

  def self.invitable_rows(params, &block)
    if block_given?
      Lister.csv_rows(params) {|r, id| block.call(r, id) }
    else
      Lister.csv_rows(params)
    end
  end
end
