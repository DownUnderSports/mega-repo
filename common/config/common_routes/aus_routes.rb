module AusRoutes
  def self.extended(router)
    router.instance_exec do
      namespace :aus do
        namespace :get_model_data do
          resources :flight_airports
          resources :flight_legs
          resources :flight_schedules
          resources :flight_tickets
          resources :inbound_domestic_flights
          resources :outbound_international_flights
          resources :sports
          resources :traveler_buses
          resources :travelers
          resources :users
        end

        resource :check_in, only: [ :create ]

        get 'valid_user/:dus_id', to: 'application#valid_user_for_path'

        get '*path', to: "application#serve_asset", constraints: ->(request) do
          !request.xhr? && (!request.format.html? || (request.path =~ /\![A-Za-z]{3,5}/))
        end

        get '*path', to: "application#fallback_index_html", constraints: ->(request) do
          !request.xhr? && request.format.html?
        end

        root to: 'application#fallback_index_html'
      end
    end
  end
end
