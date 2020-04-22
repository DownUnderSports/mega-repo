class CreateStaffs < ActiveRecord::Migration[5.2]
  def change
    create_table :staffs do |t|
      t.boolean :admin, null: false, default: false
      t.boolean :trusted, null: false, default: false
      t.boolean :management, null: false, default: false
      t.boolean :australia, null: false, default: false
      t.boolean :credits, null: false, default: false
      t.boolean :debits, null: false, default: false
      t.boolean :finances, null: false, default: false
      t.boolean :flights, null: false, default: false
      t.boolean :importing, null: false, default: false
      t.boolean :inventories, null: false, default: false
      t.boolean :meetings, null: false, default: false
      t.boolean :offers, null: false, default: false
      t.boolean :passports, null: false, default: false
      t.boolean :photos, null: false, default: false
      t.boolean :recaps, null: false, default: false
      t.boolean :remittances, null: false, default: false
      t.boolean :schools, null: false, default: false
      t.boolean :uniforms, null: false, default: false

      t.timestamps default: -> { 'NOW()' }
    end

    audit_table :staffs
  end
end
