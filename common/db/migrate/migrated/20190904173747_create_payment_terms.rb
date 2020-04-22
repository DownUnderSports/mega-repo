class CreatePaymentTerms < ActiveRecord::Migration[5.2]
  def change
    create_table :payment_terms do |t|
      t.references :edited_by, null: false, foreign_key: { to_table: :users }
      t.text :body, null: false
      t.text :minor_signed_terms_link, null: false
      t.text :adult_signed_terms_link, null: false

      t.timestamps default: -> { 'NOW()' }
    end
  end
end
