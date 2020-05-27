module APIRoutes
  def self.extended(router)
    router.instance_exec do
      namespace :api do
        post :load_errors, to: 'api/errors#load_errors'
        resources :deploys, only: [ :index, :create ]

        resources :qr_codes, only: [ :show ]

        resources :direct_uploads, only: [] do
          member do
            post :legal_form
            post :passport
          end
        end

        resources :errors, only: %i[ create ] do
          collection do
            post :load_errors
          end
        end

        resources :event_results, only: %i[ show ]

        resources :articles, only: %i[ index ]
        resources :home_gallery, only: %i[ index ]
        resources :meetings, concerns: [:versionable], only: %i[ index ] do
          member do
            get :countdown
          end
        end
        resources :nationalities, only: %i[ index ]
        resources :participants, only: %i[ index show ]
        resources :sports, only: %i[ index show ]
        resources :states, only: %i[ index ]
        resources :users, only: %i[ show ] do
          collection do
            get :current
          end
          member do
            get :traveling
            get :valid
          end
          resources :payments, only: %i[ create ]
          resources :refunds, only: %i[ create ]
        end

        resources :privacy_policies, only: %i[ index show ]
        resources :payments, only: %i[ show ], constraints: {id: /[0-9]+-[^-]+-.*/}
        resources :terms, only: %i[ index show ]
        resources :thank_you_tickets, only: %i[ index show ]
        resources :thank_you_tickets, only: %i[ index show ], path: 'thank-you-tickets'


        resources :infokits, only: %i[ new create ] do
          member do
            get :valid
          end
        end

        resources :tryouts, only: %i[ create ]

        resources :departure_checklists, only: %i[ show ], defaults: { format: :json } do
          member do
            get :passport, to: "departure_checklists#get_passport"
            post :passport, to: "departure_checklists#submit_passport"
            post :registration
            post :upload_legal_form
            post :verify_details
          end
        end

        resources :uniform_orders, only: %i[ index show update ], defaults: { format: :json }
        resources :event_registrations, only: %i[ index show update ], defaults: { format: :json }

        resources :videos, concerns: [:versionable], only: %i[ index show ] do
          member do
            post "/:tracking_id", to: 'videos#track'
            post :track
          end
        end

        resources :sessions, only: :index, defaults: { format: :json }
        resources :chat_rooms, only: :create

        resources :fundraising_ideas, only: %i[ index ]


        get 'version', to: '/application#version'
      end

      get "random-background", to: 'application#random_background'
      get "random_background", to: 'application#random_background'
    end
  end
end
