class AddAgreedToUserGeneralReleases < ActiveRecord::Migration[5.2]
  def change
    change_table :user_general_releases do |t|
      t.boolean :agreed_to_terms, null: false, default: false
    end
  end
end
