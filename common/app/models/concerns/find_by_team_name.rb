# encoding: utf-8
# frozen_string_literal: true

module FindByTeamName
  extend ActiveSupport::Concern

  module ClassMethods
    def find(*user_ids)
      if (user_ids.size == 1) && ((user_id = user_ids.first.to_s) =~ /[A-Za-z]/)
        find_by(name: user_id)
      else
        super
      end
    end

    def find_by(arg, *args)
      if arg.is_a? Hash
        key = nil
        if arg[key = :name] || arg[key = 'name']
          str = (arg[key] = arg[key].to_s.upcase).split(' ')
          if Sport[str[0]]
            arg[key] = "#{str[1]} #{str[0]}"
          end
        end
        super(arg)
      else
        super
      end
    end

    def [](key)
      find_by(name: key)
    end
  end
end
