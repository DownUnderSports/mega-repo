class DropOldAuditTables < ActiveRecord::Migration[5.2]
  def up
    execute <<-SQL
      DROP TABLE IF EXISTS #{BetterRecord.db_audit_schema}.old_logged_actions CASCADE;
      DROP TABLE IF EXISTS #{BetterRecord.db_audit_schema}.old_old_logged_actions CASCADE;
    SQL

    %i[
      active_storage_attachments
      active_storage_blobs
      addresses
      athletes
      athletes_sports
      coaches
      meeting_registrations
      meeting_video_views
      meeting_videos
      meetings
      payment_items
      payments
      schools
      shirt_order_items
      shirt_order_shipments
      shirt_orders
      sources
      sports
      staffs
      states
      student_lists
      traveler_base_debits
      traveler_credits
      traveler_debits
      traveler_offers
      travelers
      user_overrides
      user_relations
    ].each do |tbl|
      execute "DROP TRIGGER IF EXISTS audit_trigger_row ON #{tbl};"
      execute "DROP TRIGGER IF EXISTS audit_trigger_stm ON #{tbl};"
      audit_table tbl
    end

    execute "DROP TRIGGER IF EXISTS audit_trigger_row ON users;"
    execute "DROP TRIGGER IF EXISTS audit_trigger_stm ON users;"
    audit_table :users, true, false, %w[ password register_secret certificate updated_at ]
  end
end
