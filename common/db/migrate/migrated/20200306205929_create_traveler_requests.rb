class CreateTravelerRequests < ActiveRecord::Migration[5.2]
  def change
    reversible do |d|
      d.up do
        execute <<-SQL
          CREATE TYPE traveler_request_category
            AS ENUM (
              'flight',
              'medical',
              'diet',
              'room',
              'arrival',
              'departure',
              'other'
            );
        SQL
      end

      d.down do
        execute <<-SQL
          DROP TYPE traveler_request_category;
        SQL
      end
    end

    create_table :traveler_requests do |t|
      t.references :traveler, null: false, foreign_key: true
      t.column :category, :traveler_request_category, null: false
      t.text :details, null: false

      t.index [ :traveler_id, :category ]
      t.index [ :category ]

      t.timestamps default: -> { 'NOW()' }
    end

    set_table_to_yearly \
      table_name: :traveler_requests,
      foreign_keys: [
        {
          from_col: :traveler_id,
          to_table: :travelers,
          to_schema: "year_YEAR"
        }
      ]
  end
end
