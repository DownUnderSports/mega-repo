class CreateThankYouTicketTerms < ActiveRecord::Migration[5.2]
  def change
    create_table :thank_you_ticket_terms do |t|
      t.references :edited_by, null: false, foreign_key: { to_table: :users }
      t.text :body, null: false

      t.timestamps default: -> { 'NOW()' }
    end
  end
end
