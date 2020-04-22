class CreateAddressVariants < ActiveRecord::Migration[5.2]
  def change
    create_table :address_variants do |t|
      t.references :address, foreign_key: true
      t.integer :candidate_ids, null: false, array: true, default: []
      t.text :value, null: false

      t.index [ :candidate_ids ], using: 'gin'
      t.index [ :value ], unique: true
    end

    reversible do |d|
      d.up do
        execute <<-SQL
          CREATE INDEX address_variants_candidate_ids_count_idx
          ON address_variants (
            array_upper(candidate_ids, 1)
          )
        SQL
      end

      d.down do
        execute "DROP INDEX address_variants_candidate_ids_count_idx;"
      end
    end
  end
end
