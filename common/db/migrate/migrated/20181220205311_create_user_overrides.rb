class CreateUserOverrides < ActiveRecord::Migration[5.2]
  def change
    create_table :user_overrides do |t|
      t.references :user, null: false, foreign_key: true
      t.text :payment_description

      t.timestamps default: -> { 'NOW()' }
    end

    audit_table :user_overrides
  end
end
