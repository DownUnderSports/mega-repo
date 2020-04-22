class CreateUserEventRegistrations < ActiveRecord::Migration[5.2]
  def change
    create_table :user_event_registrations do |t|
      t.references :user, null: false, foreign_key: true
      t.references :submitter, foreign_key: { to_table: :users }

      [
        '100 M',
        '200 M',
        '400 M',
        '800 M',
        '1500 M',
        '3000 M',
        '90 M Hurdles',
        '100 M Hurdles',
        '110 M Hurdles',
        '200 M Hurdles',
        '300 M Hurdles',
        '400 M Hurdles',
        '2000 M Steeple',
        'Long Jump',
        'Triple Jump',
        'High Jump',
        'Pole Vault',
        'Shot Put',
        'Discus',
        'Javelin',
        'Hammer',
        '3000 M Walk',
        '5000 M Walk',
      ].each do |event|
        underscored = "event_#{event.parameterize.underscore}"
        t.text underscored.to_sym, array: true, default: []
        t.integer "#{underscored}_count".to_sym, default: 0, null: false
        t.text "#{underscored}_time".to_sym
      end

      t.text :one_hundred_m_relay
      t.text :four_hundred_m_relay

      t.timestamps default: -> { 'NOW()' }
    end

    audit_table :user_event_registrations
  end
end
