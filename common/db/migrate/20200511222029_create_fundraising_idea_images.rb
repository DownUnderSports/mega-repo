class CreateFundraisingIdeaImages < ActiveRecord::Migration[5.2]
  def change
    create_table :fundraising_idea_images do |t|
      t.references :fundraising_idea, null: false, foreign_key: true
      t.text :alt
      t.integer :display_order
      t.boolean :hide, null: false, default: false

      t.index [ :display_order ]
      t.index [ :hide ]

      t.timestamps default: -> { 'NOW()' }
    end
  end
end
