class CreateThankYouTickets < ActiveRecord::Migration[5.2]
  def change
    create_table :thank_you_tickets do |t|
      t.references :user, index: true, foreign_key: true
      t.uuid :uuid, null: false, default: -> { 'uuid_generate_v6()' }
      t.text :name
      t.text :email
      t.text :phone
      t.text :mailing_address

      t.index [ :uuid ], unique: true
      t.index [ :name ], name: "thank_you_ticket_name_index",
                         where: "thank_you_tickets.name IS NOT NULL"

      t.timestamps default: -> { 'NOW()' }
    end
  end
end
