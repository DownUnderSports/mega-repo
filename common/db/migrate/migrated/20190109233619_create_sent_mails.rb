class CreateSentMails < ActiveRecord::Migration[5.2]
  def change
    create_table :sent_mails do |t|
      t.text :name
      t.datetime :created_at, default: -> { 'NOW()' }
    end
  end
end
