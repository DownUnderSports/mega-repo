# This migration comes from better_record (originally 20180518042070)
class CreateBetterRecordTableSizes < ActiveRecord::Migration[5.2]
  def change
    create_table "#{BetterRecord.db_audit_schema}.table_sizes", {id: false} do |t|
      t.integer :oid, limit: 8
      t.string :schema
      t.string :name
      t.float :apx_row_count
      t.integer :total_bytes, limit: 8
      t.integer :idx_bytes, limit: 8
      t.integer :toast_bytes, limit: 8
      t.integer :tbl_bytes, limit: 8
      t.text :total
      t.text :idx
      t.text :toast
      t.text :tbl
    end

    reversible do |d|
      d.up do
        execute "ALTER TABLE #{BetterRecord.db_audit_schema}.table_sizes ADD PRIMARY KEY (oid);"
      end
    end
  end
end
