class CreateUserRefundRequests < ActiveRecord::Migration[5.2]
  def change
    create_table :user_refund_requests do |t|
      t.references :user, null: false, foreign_key: true
      t.text :value

      t.timestamps default: -> { 'NOW()' }
    end
  end
end
