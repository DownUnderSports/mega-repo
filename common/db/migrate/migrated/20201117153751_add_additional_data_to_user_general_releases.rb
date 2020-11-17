class AddAdditionalDataToUserGeneralReleases < ActiveRecord::Migration[5.2]
  def change
    change_table :user_general_releases do |t|
      t.jsonb :additional_data, null: false, default: "{}"

      t.index [ :additional_data ], using: "gin"
    end
  end
end
