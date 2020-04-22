# encoding: utf-8
# frozen_string_literal: true

module ActiveStorageAttachmentExtensions
  extend ActiveSupport::Concern

  included do
    after_commit :attachment_created_callback, on: %i[ create ]
    after_commit :attachment_destroyed_callback, on: %i[ destroy ]
  end

  module ClassMethods
    def included_attachment_extension_placeholder
      true
    end
  end

  def read_bytes(*args)
    blob.read_bytes(*args)
  end

  def is_zip?
    blob.is_zip?
  end

  private
    def attachment_created_callback
      if record.respond_to?(created_callback_name, true)
        record.__send__ created_callback_name, self
      end

      attachment_generic_callback :create

      true
    end

    def attachment_destroyed_callback
      if record.respond_to?(destroyed_callback_name, true)
        record.__send__ destroyed_callback_name, self
      end

      attachment_generic_callback :destroy

      true
    end

    def attachment_generic_callback(type)
      if record.respond_to?(generic_callback_name, true)
        record.__send__ generic_callback_name, self, type
      end
    end

    def created_callback_name
      :"after_#{self.name}_attachment_created"
    end

    def destroyed_callback_name
      :"after_#{self.name}_attachment_destroyed"
    end

    def generic_callback_name
      :"after_#{self.name}_attachment_commit"
    end
end
