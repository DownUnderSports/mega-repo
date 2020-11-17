class CreateUserGeneralReleases < ActiveRecord::Migration[5.2]
  def change
    create_table :user_general_releases do |t|
      t.references :user, null: false, foreign_key: true
      t.boolean :is_signed, null: false, default: false
      t.boolean :allow_contact, null: false, default: false
      t.exchange_rate_integer :percentage_paid, null: false
      t.integer :net_refundable
      t.text :notes

      t.timestamps default: -> { 'NOW()' }
    end
  end
end
