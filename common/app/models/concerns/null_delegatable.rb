# encoding: utf-8
# frozen_string_literal: true

module NullDelegatable
  extend ActiveSupport::Concern

  module ClassMethods
    def delegate_blank(*methods, to:, prefix: :delegated, default: nil, **opts)
      delegate *methods, to: to, prefix: prefix

      methods.each do |method|
        define_method method do
          self[method].blank? ? __send__(:"#{prefix}_#{method}") || default : self[method]
        end

        define_method :"#{method}_is_delegated?" do
          self[method].blank?
        end
      end
    end
  end
end
