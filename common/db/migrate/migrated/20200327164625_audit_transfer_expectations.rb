class AuditTransferExpectations < ActiveRecord::Migration[5.2]
  def up
    audit_yearly_table :user_transfer_expectations
  end
end
