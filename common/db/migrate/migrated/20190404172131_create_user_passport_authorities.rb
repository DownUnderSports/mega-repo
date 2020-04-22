class CreateUserPassportAuthorities < ActiveRecord::Migration[5.2]
  def change
    create_table :user_passport_authorities do |t|
      t.text :name, null: false
      t.index [ :name ], unique: true
    end
  end
end
