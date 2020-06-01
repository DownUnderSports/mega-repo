class CreateFundraisingIdeas < ActiveRecord::Migration[5.2]
  def change
    create_table :fundraising_ideas do |t|
      t.text :title, null: false
      t.text :description
      t.integer :display_order

      t.timestamps default: -> { 'NOW()' }
    end
  end
end
