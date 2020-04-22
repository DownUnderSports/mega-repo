class CreateInterests < ActiveRecord::Migration[5.2]
  def change
    create_table :interests do |t|
      t.text :level
      t.boolean :contactable, null: false, default: false
    end
    
    reversible do |d|
      d.up do
        [
          { id: 1, level: "Traveling", contactable: true },
          { id: 2, level: "Sending Deposit", contactable: true },
          { id: 3, level: "Interested", contactable: true },
          { id: 4, level: "Curious", contactable: true },
          { id: 5, level: "Unknown", contactable: true },
          { id: 6, level: "Next Year", contactable: false },
          { id: 7, level: "Maybe Next Year", contactable: false },
          { id: 8, level: "No Respond", contactable: false },
          { id: 9, level: "Not Going", contactable: false },
          { id: 10, level: "Never", contactable: false },
          { id: 11, level: "Restricted", contactable: false }
        ].each do |i|
          Interest.create!(**i) unless Interest.find_by(id: i[:id])
        end
      end
    end
  end
end
