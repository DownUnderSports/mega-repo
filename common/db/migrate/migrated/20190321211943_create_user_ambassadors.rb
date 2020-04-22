class CreateUserAmbassadors < ActiveRecord::Migration[5.2]
  def change
    create_table :user_ambassadors do |t|
      t.references :user, null: false, foreign_key: true
      t.references :ambassador_user, null: false, foreign_key: { to_table: :users }
      t.text :types_array, null: false, array: true, default: []

      t.timestamps default: -> { 'NOW()' }
    end

    audit_table :user_ambassadors
  end
end
