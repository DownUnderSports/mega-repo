class UpdateAllAuditFunctions < ActiveRecord::Migration[5.2]
  def up
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
      officials
      payment_items
      payment_remittances
      payments
      schools
      shirt_order_items
      shirt_order_shipments
      shirt_orders
      sources
      sports
      staff_assignments
      staffs
      states
      student_lists
      traveler_base_debits
      traveler_credits
      traveler_debits
      traveler_offers
      travelers
      user_ambassadors
      user_event_registrations
      user_overrides
      user_relations
      user_uniform_orders
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
