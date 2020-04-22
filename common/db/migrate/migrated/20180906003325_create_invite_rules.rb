class CreateInviteRules < ActiveRecord::Migration[5.2]
  def change
    create_table :invite_rules do |t|
      t.references :sport, null: false, foreign_key: true
      t.references :state, null: false, foreign_key: true
      t.boolean :invitable, null: false, default: false
      t.boolean :certifiable, null: false, default: false
      t.integer :grad_year, null: false, default: 2022

      t.datetime :updated_at, null: false, default: -> { 'NOW()' }
    end
  end
end
