class CreateUnsubscribers < ActiveRecord::Migration[5.2]
  def change
    create_table :unsubscribers do |t|
      t.unsubscriber_category :category
      t.text :value, null: false
      t.boolean :all, null: false, default: true

      t.index [ :category, :value ], unique: true

      t.timestamps default: -> { 'NOW()' }
    end
  end
end
