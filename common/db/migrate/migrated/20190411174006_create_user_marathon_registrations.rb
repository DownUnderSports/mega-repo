class CreateUserMarathonRegistrations < ActiveRecord::Migration[5.2]
  def change
    create_table :user_marathon_registrations do |t|
      t.references :user, null: false, foreign_key: true

      t.date :registered_date
      t.text :confirmation
      t.text :email, default: 'gcm-registrations@downundersports.com'

      t.timestamps default: -> { 'NOW()' }
    end

    audit_table :user_marathon_registrations
  end
end
