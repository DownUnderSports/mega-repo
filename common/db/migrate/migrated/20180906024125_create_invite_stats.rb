class CreateInviteStats < ActiveRecord::Migration[5.2]
  def change
    create_table :invite_stats do |t|
      t.date :submitted
      t.date :mailed
      t.integer :estimated
      t.integer :actual

      t.datetime :updated_at, null: false, default: -> { 'NOW()' }
    end
  end
end
