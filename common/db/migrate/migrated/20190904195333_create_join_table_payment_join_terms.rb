class CreateJoinTablePaymentJoinTerms < ActiveRecord::Migration[5.2]
  def up
    create_table :payment_join_terms do |t|
      t.integer :payment_id, null: false
      t.integer :terms_id, null: false

      t.index [ :payment_id ]

      t.timestamps default: -> { 'NOW()' }
    end

    set_table_to_yearly \
      table_name: :payment_join_terms,
      foreign_keys: [
        {
          from_col: "terms_id",
          to_table: "payment_terms",
          to_schema: "public"
        },
        {
          from_col: "payment_id",
          to_table: "payments",
          to_schema: "year_YEAR"
        }
      ]
  end

  def down
    execute <<-SQL
      DROP TABLE IF EXISTS public.payment_join_terms CASCADE
    SQL
  end
end
