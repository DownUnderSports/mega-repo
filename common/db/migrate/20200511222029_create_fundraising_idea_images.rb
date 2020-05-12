class CreateFundraisingIdeaImages < ActiveRecord::Migration[5.2]
  def change
    create_table :fundraising_idea_images do |t|
      t.text :alt
      t.integer :display_order

      t.timestamps default: -> { 'NOW()' }
    end
  end
end
