# This migration comes from better_record (originally 20181228204403)
class CreateBetterRecordAttachmentValidations < ActiveRecord::Migration[5.2]
  def change
    create_table :better_record_attachment_validations do |t|
      t.text     :name,       null: false
      t.references :attachment, null: false
      t.boolean    :ran,        null: false, default: false

      t.index [ :attachment_id, :name ], name: "index_attachment_validations_uniqueness", unique: true

      t.timestamps default: -> { 'NOW()' }
    end
  end
end
