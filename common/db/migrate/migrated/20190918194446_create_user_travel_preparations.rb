class CreateUserTravelPreparations < ActiveRecord::Migration[5.2]
  def up
    create_table :user_travel_preparations do |t|
      t.integer :user_id, null: false

      t.index [ :user_id ]

      t.date :joined_team_followup_date
      t.date :domestic_followup_date
      t.date :insurance_followup_date
      t.date :checklist_followup_date

      t.date :address_confirmed_date
      t.date :dob_confirmed_date
      t.date :fundraising_packet_received_date
      t.date :travel_packet_received_date
      t.date :applied_for_passport_date
      t.date :applied_for_eta_date

      t.date :eta_email_date
      t.date :visa_message_sent_date

      t.boolean :extra_eta_processing, null: false, default: false

      t.three_state :has_multiple_citizenships, null: false, default: 'U'
      t.text :citizenships_array, null: false, array: true, default: []

      t.three_state :has_aliases, null: false, default: 'U'
      t.string :aliases_array, null: false, array: true, default: []

      t.three_state :has_convictions, null: false, default: 'U'
      t.text :convictions_array, null: false, array: true, default: []


      t.timestamps default: -> { 'NOW()' }
    end

    set_table_to_yearly \
      table_name: :user_travel_preparations,
      foreign_keys: [
        {
          from_col: :user_id,
          to_table: :users,
          to_schema: :public
        }
      ]

    execute <<-SQL
      INSERT INTO "year_2019"."user_travel_preparations"
      (
        user_id,
        extra_eta_processing,
        has_multiple_citizenships,
        citizenships_array,
        has_aliases,
        aliases_array,
        has_convictions,
        convictions_array,
        eta_email_date,
        visa_message_sent_date
      )
      SELECT
        user_id,
        extra_eta_processing,
        has_multiple_citizenships,
        citizenships_array,
        has_aliases,
        aliases_array,
        has_convictions,
        convictions_array,
        eta_email_date,
        visa_message_sent_date
      FROM public.user_passports
    SQL

    remove_column :user_passports, :extra_eta_processing
    remove_column :user_passports, :has_multiple_citizenships
    remove_column :user_passports, :citizenships_array
    remove_column :user_passports, :has_aliases
    remove_column :user_passports, :aliases_array
    remove_column :user_passports, :has_convictions
    remove_column :user_passports, :convictions_array
    remove_column :user_passports, :eta_email_date
    remove_column :user_passports, :visa_message_sent_date

    audit_table :user_travel_preparations
  end

  def down
    raise ActiveRecord::IrreversibleMigration
  end
end
