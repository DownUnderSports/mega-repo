class AddReconciledToPayments < ActiveRecord::Migration[5.2]
  def change
    change_table("public.payments") do |t|
      t.date :reconciled_date
    end
  end
end
