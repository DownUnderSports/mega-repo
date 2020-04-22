class CreateUserTransferExpectations < ActiveRecord::Migration[5.2]
  def change
    reversible do |d|
      d.up do
        execute <<-SQL
          CREATE TYPE difficulty_level
            AS ENUM (
              'extreme',
              'hard',
              'moderate',
              'easy',
              'none'
            );
        SQL
      end

      d.down do
        execute <<-SQL
          DROP TYPE difficulty_level;
        SQL
      end
    end

    reversible do |d|
      d.up do
        execute <<-SQL
          CREATE TYPE transfer_contact_status
            AS ENUM (
              'evaluated',
              'contacted',
              'confirmed',
              'completed'
            );
        SQL
      end

      d.down do
        execute <<-SQL
          DROP TYPE transfer_contact_status;
        SQL
      end
    end

    create_table :user_transfer_expectations do |t|
      t.integer :user_id, null: false
      t.column :difficulty, :difficulty_level
      t.column :status, :transfer_contact_status
      t.three_state :can_transfer, null: false, default: 'U'
      t.three_state :can_compete, null: false, default: 'U'
      t.text :notes

      t.jsonb :offer, null: false, default: '{}'

      t.index [ :user_id ]
      t.index [ :difficulty, :status ], name: 'expected_difficulty_and_status_index'
      t.index [ :status, :difficulty ], name: 'expected_status_and_difficulty_index'
      t.index [ :can_transfer, :can_compete ], name: 'expected_transfer_and_compete_index'

      t.timestamps default: -> { 'NOW()' }
    end

    set_table_to_yearly \
      table_name: :user_transfer_expectations,
      foreign_keys: [
        {
          from_col: :user_id,
          to_table: :users,
          to_schema: :public
        }
      ]
  end
end
