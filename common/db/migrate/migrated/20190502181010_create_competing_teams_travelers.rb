class CreateCompetingTeamsTravelers < ActiveRecord::Migration[5.2]
  def change
    create_table :competing_teams_travelers do |t|
      t.references :competing_team, null: false, foreign_key: true
      t.references :traveler, null: false, foreign_key: true
    end

    audit_table :competing_teams_travelers

    reversible do |d|
      d.up do
        execute <<-SQL
          ALTER TABLE public.active_storage_attachments SET (autovacuum_vacuum_threshold='50');
          ALTER TABLE public.active_storage_attachments SET (autovacuum_vacuum_scale_factor='0.2');
          ALTER TABLE public.active_storage_blobs SET (autovacuum_vacuum_threshold='50');
          ALTER TABLE public.active_storage_blobs SET (autovacuum_vacuum_scale_factor='0.2');
          ALTER TABLE public.address_variants SET (autovacuum_vacuum_threshold='50');
          ALTER TABLE public.address_variants SET (autovacuum_vacuum_scale_factor='0.2');
          ALTER TABLE public.addresses SET (autovacuum_vacuum_threshold='50');
          ALTER TABLE public.addresses SET (autovacuum_vacuum_scale_factor='0.2');
          ALTER TABLE public.ar_internal_metadata SET (autovacuum_vacuum_threshold='50');
          ALTER TABLE public.ar_internal_metadata SET (autovacuum_vacuum_scale_factor='0.2');
          ALTER TABLE public.athletes SET (autovacuum_vacuum_threshold='50');
          ALTER TABLE public.athletes SET (autovacuum_vacuum_scale_factor='0.2');
          ALTER TABLE public.athletes_sports SET (autovacuum_vacuum_threshold='50');
          ALTER TABLE public.athletes_sports SET (autovacuum_vacuum_scale_factor='0.2');
          ALTER TABLE public.better_record_attachment_validations SET (autovacuum_vacuum_threshold='50');
          ALTER TABLE public.better_record_attachment_validations SET (autovacuum_vacuum_scale_factor='0.2');
          ALTER TABLE public.coaches SET (autovacuum_vacuum_threshold='50');
          ALTER TABLE public.coaches SET (autovacuum_vacuum_scale_factor='0.2');
          ALTER TABLE public.competing_teams SET (autovacuum_vacuum_threshold='50');
          ALTER TABLE public.competing_teams SET (autovacuum_vacuum_scale_factor='0.2');
          ALTER TABLE public.competing_teams_travelers SET (autovacuum_vacuum_threshold='50');
          ALTER TABLE public.competing_teams_travelers SET (autovacuum_vacuum_scale_factor='0.2');
          ALTER TABLE public.import_athletes SET (autovacuum_vacuum_threshold='50');
          ALTER TABLE public.import_athletes SET (autovacuum_vacuum_scale_factor='0.2');
          ALTER TABLE public.import_backups SET (autovacuum_vacuum_threshold='50');
          ALTER TABLE public.import_backups SET (autovacuum_vacuum_scale_factor='0.2');
          ALTER TABLE public.import_errors SET (autovacuum_vacuum_threshold='50');
          ALTER TABLE public.import_errors SET (autovacuum_vacuum_scale_factor='0.2');
          ALTER TABLE public.import_matches SET (autovacuum_vacuum_threshold='50');
          ALTER TABLE public.import_matches SET (autovacuum_vacuum_scale_factor='0.2');
          ALTER TABLE public.interests SET (autovacuum_vacuum_threshold='50');
          ALTER TABLE public.interests SET (autovacuum_vacuum_scale_factor='0.2');
          ALTER TABLE public.invite_rules SET (autovacuum_vacuum_threshold='50');
          ALTER TABLE public.invite_rules SET (autovacuum_vacuum_scale_factor='0.2');
          ALTER TABLE public.invite_stats SET (autovacuum_vacuum_threshold='50');
          ALTER TABLE public.invite_stats SET (autovacuum_vacuum_scale_factor='0.2');
          ALTER TABLE public.mailings SET (autovacuum_vacuum_threshold='50');
          ALTER TABLE public.mailings SET (autovacuum_vacuum_scale_factor='0.2');
          ALTER TABLE public.meeting_registrations SET (autovacuum_vacuum_threshold='50');
          ALTER TABLE public.meeting_registrations SET (autovacuum_vacuum_scale_factor='0.2');
          ALTER TABLE public.meeting_video_views SET (autovacuum_vacuum_threshold='50');
          ALTER TABLE public.meeting_video_views SET (autovacuum_vacuum_scale_factor='0.2');
          ALTER TABLE public.meeting_videos SET (autovacuum_vacuum_threshold='50');
          ALTER TABLE public.meeting_videos SET (autovacuum_vacuum_scale_factor='0.2');
          ALTER TABLE public.meetings SET (autovacuum_vacuum_threshold='50');
          ALTER TABLE public.meetings SET (autovacuum_vacuum_scale_factor='0.2');
          ALTER TABLE public.officials SET (autovacuum_vacuum_threshold='50');
          ALTER TABLE public.officials SET (autovacuum_vacuum_scale_factor='0.2');
          ALTER TABLE public.participants SET (autovacuum_vacuum_threshold='50');
          ALTER TABLE public.participants SET (autovacuum_vacuum_scale_factor='0.2');
          ALTER TABLE public.payment_items SET (autovacuum_vacuum_threshold='50');
          ALTER TABLE public.payment_items SET (autovacuum_vacuum_scale_factor='0.2');
          ALTER TABLE public.payment_remittances SET (autovacuum_vacuum_threshold='50');
          ALTER TABLE public.payment_remittances SET (autovacuum_vacuum_scale_factor='0.2');
          ALTER TABLE public.payments SET (autovacuum_vacuum_threshold='50');
          ALTER TABLE public.payments SET (autovacuum_vacuum_scale_factor='0.2');
          ALTER TABLE public.schema_migrations SET (autovacuum_vacuum_threshold='50');
          ALTER TABLE public.schema_migrations SET (autovacuum_vacuum_scale_factor='0.2');
          ALTER TABLE public.schools SET (autovacuum_vacuum_threshold='50');
          ALTER TABLE public.schools SET (autovacuum_vacuum_scale_factor='0.2');
          ALTER TABLE public.sent_mails SET (autovacuum_vacuum_threshold='50');
          ALTER TABLE public.sent_mails SET (autovacuum_vacuum_scale_factor='0.2');
          ALTER TABLE public.shirt_order_items SET (autovacuum_vacuum_threshold='50');
          ALTER TABLE public.shirt_order_items SET (autovacuum_vacuum_scale_factor='0.2');
          ALTER TABLE public.shirt_order_shipments SET (autovacuum_vacuum_threshold='50');
          ALTER TABLE public.shirt_order_shipments SET (autovacuum_vacuum_scale_factor='0.2');
          ALTER TABLE public.shirt_orders SET (autovacuum_vacuum_threshold='50');
          ALTER TABLE public.shirt_orders SET (autovacuum_vacuum_scale_factor='0.2');
          ALTER TABLE public.sources SET (autovacuum_vacuum_threshold='50');
          ALTER TABLE public.sources SET (autovacuum_vacuum_scale_factor='0.2');
          ALTER TABLE public.sport_events SET (autovacuum_vacuum_threshold='50');
          ALTER TABLE public.sport_events SET (autovacuum_vacuum_scale_factor='0.2');
          ALTER TABLE public.sport_infos SET (autovacuum_vacuum_threshold='50');
          ALTER TABLE public.sport_infos SET (autovacuum_vacuum_scale_factor='0.2');
          ALTER TABLE public.sports SET (autovacuum_vacuum_threshold='50');
          ALTER TABLE public.sports SET (autovacuum_vacuum_scale_factor='0.2');
          ALTER TABLE public.staff_assignment_visits SET (autovacuum_vacuum_threshold='50');
          ALTER TABLE public.staff_assignment_visits SET (autovacuum_vacuum_scale_factor='0.2');
          ALTER TABLE public.staff_assignments SET (autovacuum_vacuum_threshold='50');
          ALTER TABLE public.staff_assignments SET (autovacuum_vacuum_scale_factor='0.2');
          ALTER TABLE public.staffs SET (autovacuum_vacuum_threshold='50');
          ALTER TABLE public.staffs SET (autovacuum_vacuum_scale_factor='0.2');
          ALTER TABLE public.states SET (autovacuum_vacuum_threshold='50');
          ALTER TABLE public.states SET (autovacuum_vacuum_scale_factor='0.2');
          ALTER TABLE public.student_lists SET (autovacuum_vacuum_threshold='50');
          ALTER TABLE public.student_lists SET (autovacuum_vacuum_scale_factor='0.2');
          ALTER TABLE public.teams SET (autovacuum_vacuum_threshold='50');
          ALTER TABLE public.teams SET (autovacuum_vacuum_scale_factor='0.2');
          ALTER TABLE public.traveler_base_debits SET (autovacuum_vacuum_threshold='50');
          ALTER TABLE public.traveler_base_debits SET (autovacuum_vacuum_scale_factor='0.2');
          ALTER TABLE public.traveler_credits SET (autovacuum_vacuum_threshold='50');
          ALTER TABLE public.traveler_credits SET (autovacuum_vacuum_scale_factor='0.2');
          ALTER TABLE public.traveler_debits SET (autovacuum_vacuum_threshold='50');
          ALTER TABLE public.traveler_debits SET (autovacuum_vacuum_scale_factor='0.2');
          ALTER TABLE public.traveler_offers SET (autovacuum_vacuum_threshold='50');
          ALTER TABLE public.traveler_offers SET (autovacuum_vacuum_scale_factor='0.2');
          ALTER TABLE public.travelers SET (autovacuum_vacuum_threshold='50');
          ALTER TABLE public.travelers SET (autovacuum_vacuum_scale_factor='0.2');
          ALTER TABLE public.unsubscribers SET (autovacuum_vacuum_threshold='50');
          ALTER TABLE public.unsubscribers SET (autovacuum_vacuum_scale_factor='0.2');
          ALTER TABLE public.user_ambassadors SET (autovacuum_vacuum_threshold='50');
          ALTER TABLE public.user_ambassadors SET (autovacuum_vacuum_scale_factor='0.2');
          ALTER TABLE public.user_event_registrations SET (autovacuum_vacuum_threshold='50');
          ALTER TABLE public.user_event_registrations SET (autovacuum_vacuum_scale_factor='0.2');
          ALTER TABLE public.user_forwarded_ids SET (autovacuum_vacuum_threshold='50');
          ALTER TABLE public.user_forwarded_ids SET (autovacuum_vacuum_scale_factor='0.2');
          ALTER TABLE public.user_marathon_registrations SET (autovacuum_vacuum_threshold='50');
          ALTER TABLE public.user_marathon_registrations SET (autovacuum_vacuum_scale_factor='0.2');
          ALTER TABLE public.user_messages SET (autovacuum_vacuum_threshold='50');
          ALTER TABLE public.user_messages SET (autovacuum_vacuum_scale_factor='0.2');
          ALTER TABLE public.user_nationalities SET (autovacuum_vacuum_threshold='50');
          ALTER TABLE public.user_nationalities SET (autovacuum_vacuum_scale_factor='0.2');
          ALTER TABLE public.user_overrides SET (autovacuum_vacuum_threshold='50');
          ALTER TABLE public.user_overrides SET (autovacuum_vacuum_scale_factor='0.2');
          ALTER TABLE public.user_passport_authorities SET (autovacuum_vacuum_threshold='50');
          ALTER TABLE public.user_passport_authorities SET (autovacuum_vacuum_scale_factor='0.2');
          ALTER TABLE public.user_relations SET (autovacuum_vacuum_threshold='50');
          ALTER TABLE public.user_relations SET (autovacuum_vacuum_scale_factor='0.2');
          ALTER TABLE public.user_relationship_types SET (autovacuum_vacuum_threshold='50');
          ALTER TABLE public.user_relationship_types SET (autovacuum_vacuum_scale_factor='0.2');
          ALTER TABLE public.user_uniform_orders SET (autovacuum_vacuum_threshold='50');
          ALTER TABLE public.user_uniform_orders SET (autovacuum_vacuum_scale_factor='0.2');
          ALTER TABLE public.users SET (autovacuum_vacuum_threshold='50');
          ALTER TABLE public.users SET (autovacuum_vacuum_scale_factor='0.2');
          ALTER TABLE public.view_trackers SET (autovacuum_vacuum_threshold='50');
          ALTER TABLE public.view_trackers SET (autovacuum_vacuum_scale_factor='0.2');
        SQL
      end
    end
  end
end
