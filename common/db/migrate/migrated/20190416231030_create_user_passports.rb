class CreateUserPassports < ActiveRecord::Migration[5.2]
  def change
    create_table :user_passports do |t|
      t.references :user, null: false, foreign_key: true
      t.references :checker, foreign_key: { to_table: :users }
      t.references :second_checker, foreign_key: { to_table: :users }

      t.text :type, default: -> { "'P'::text" }
      t.text :code, default: -> { "'USA'::text" }
      t.text :nationality, default: -> { "'UNITED STATES OF AMERICA'::text" }
      t.text :authority, default: -> { "'United States Department of State'::text" }

      t.text :number
      t.text :surname
      t.text :given_names
      t.gender :sex
      t.text :birthplace
      t.date :birth_date
      t.date :issued_date
      t.date :expiration_date

      t.text :country_of_birth

      t.three_state :has_multiple_citizenships, null: false, default: 'U'
      t.text :citizenships_array, null: false, array: true, default: []

      t.three_state :has_aliases, null: false, default: 'U'
      t.string :aliases_array, null: false, array: true, default: []

      t.three_state :has_convictions, null: false, default: 'U'
      t.text :convictions_array, null: false, array: true, default: []

      t.date :eta_email_date
      t.date :visa_message_sent_date

      t.boolean :extra_eta_processing, null: false, default: false

      t.timestamps default: -> { 'NOW()' }
    end
  end
end
