class CreateUserInterestHistories < ActiveRecord::Migration[5.2]
  def change
    create_table :user_interest_histories do |t|
      t.references :user, null: false, foreign_key: true
      t.references :interest, null: false, foreign_key: true
      t.references :changed_by, null: true, foreign_key: { to_table: :users }
      t.datetime :created_at, null: false, default: -> { 'NOW()' }

      t.index [ :user_id, :created_at ], order: { created_at: :desc }
    end
  end
end
