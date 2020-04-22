module TravelRoutes
  def self.extended(router)
    router.instance_exec do
      extend DashedRoutes

      namespace :travel do
        namespace :get_model_data do
          resources :flight_airports
          resources :flight_legs
          resources :flight_schedules
          resources :flight_tickets
          resources :travelers
          resources :users
        end

        resources :my_info, dashed: true, only: [ :show ] do
          member do
            get :flights, defaults: { format: :pdf }
            get :teammates, defaults: { format: :pdf }
          end
        end

        get "my-info/:id/teammates", to: 'my_info#teammates'

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
