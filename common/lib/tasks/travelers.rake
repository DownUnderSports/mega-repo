# encoding: utf-8
# frozen_string_literal: true

namespace :travelers do
  desc 'Normalize Package Details for Travelers'
  task set_details: :environment do
    Traveler.set_balances
    Traveler.active {|t| t.set_details should_save_details: true }
  end

  desc 'Verify and Save Insurance Prices for Travelers'
  task set_insurance_prices: :environment do
    Traveler.set_balances
    Traveler.active {|t| t.set_insurance_price }
  end
end
