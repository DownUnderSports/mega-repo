# frozen_string_literal: true

ActiveSupport.on_load(:active_record) do
  module ActiveRecord
    module ConnectionAdapters
      class TableDefinition
        include Unsubscriber::Category::TableDefinition
      end
    end
  end
end

ActiveRecord::Type.register(:unsubscriber_category, Unsubscriber::Category::Type)
