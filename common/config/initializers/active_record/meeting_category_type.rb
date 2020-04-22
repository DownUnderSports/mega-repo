# frozen_string_literal: true
begin
  ActiveSupport.on_load(:active_record) do
    module ActiveRecord
      module ConnectionAdapters
        class TableDefinition
          include Meeting::Category::TableDefinition
        end
      end
    end
  end

  ActiveRecord::Type.register(:meeting_category, Meeting::Category::Type)

rescue ActiveRecord::NoDatabaseError
end
