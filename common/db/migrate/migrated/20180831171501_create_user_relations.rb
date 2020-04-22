class CreateUserRelations < ActiveRecord::Migration[5.2]
  def change
    create_table :user_relations do |t|
      t.references :user
      t.references :related_user, foreign_key: { to_table: :users }
      t.text :relationship, foreign_key: { to_table: :user_relationship_types, column: :value }

      t.timestamps default: -> { 'NOW()' }
    end
    
    audit_table :user_relations
  end
end
