# This migration comes from better_record (originally 20190107202602)
class AddUpdatedAtToBetterRecordTableSizes < ActiveRecord::Migration[5.2]
  def change
    add_column("#{BetterRecord.db_audit_schema}.table_sizes", :updated_at, :datetime, default: -> { 'NOW()'})
  end
end
