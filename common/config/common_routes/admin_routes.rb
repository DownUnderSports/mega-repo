module AdminRoutes
  AUTHORIZED_DOMAIN_TEST = %r{
    ^
    auth(enticate|orize)
    (?:
      \.localhost
      |\.lvh(\.me)?
      |\.downundersports(\.com)?
    )?
    $
  }x.freeze

  def self.with_auth(router)
    router.instance_exec do
      self.class.define_method(:with_auth) do |&block|
        constraints(subdomain: AUTHORIZED_DOMAIN_TEST) { block.call }
      end
    end
  end

  def self.extended(router)
    with_auth(router)
    router.instance_exec do
      namespace :admin do
        get :whats_my_url, to: 'application#whats_my_url'
        get :no_op, to: 'application#no_op'

        with_auth do
          get :test_departure_checklist, to: "users#test_departure_checklist"

          resources :sampson, only: [ :index, :create ]

          resources :clocks, only: [ :index, :show, :create, :edit, :update, :destroy ]

          resources :authentication, defaults: { format: :json }, only: [ :index ]
          match 'authentication' => 'authentication#preflight', via: :options

          resources :certificates, only: %i[ index create ]

          resources :uniform_orders, only: %i[ index show ] do
            collection do
              get :stamps
            end
          end

          resources :emergency_contacts, only: %i[ index show ]

          resources :chat_rooms, only: %i[ index show destroy ]

          resources :print_packets, only: %i[ index ] do
            collection do
              get :travel_card, defaults: { format: :pdf }
              get :travel_page, defaults: { format: :pdf }
              get :teammates, defaults: { format: :pdf }
              get :get_sheet, defaults: { format: :csv }
            end

            member do
              get :travel_card, defaults: { format: :pdf }
              get :travel_page, defaults: { format: :pdf }
              get :teammates, defaults: { format: :pdf }
            end
          end

          namespace :nerds do
            require 'sidekiq/web'
            require 'sidekiq-status/web'
            mount Sidekiq::Web => '/sidekiq'
            mount BetterRecord::Engine => "/"
          end

          namespace :contact_lists do
            get :school_addresses, defaults: { format: :csv }
            get :bonus_travel_packet_mailings, defaults: { format: :csv }
            get :dbag_mailings, defaults: { format: :csv }
            get :fb_travelers, defaults: { format: :csv }
            get :gbr_letter, defaults: { format: :csv }
            get :gbr_travelers, defaults: { format: :csv }
            get "jersey_numbers_by_team/:sport_id", action: :jersey_numbers_by_team, as: :jersey_numbers_by_team, defaults: { format: :csv }
            get :missing_event_reg, defaults: { format: :csv }
            get :missing_legal_docs, defaults: { format: :csv }
            get "missing_uniforms/:sport_id", action: :missing_uniforms, as: :missing_uniform, defaults: { format: :csv }
            get :mtg_postcard, defaults: { format: :csv }
            get "sport_travelers(/:sport)", action: :sport_travelers, as: :sport_travelers, defaults: { format: :csv }
            get :new_year_student_lists, defaults: { format: :csv }
          end

          namespace :imports do
            root to: 'uploads#show'

            resource :upload, only: [:show, :create]
            resource :url, only: [:show, :create]
          end

          namespace :fundraising_packets do
            root to: 'uploads#show'

            resource :upload, only: [:show, :create]
          end
        end

        namespace :accounting do
          resources :checks, only: :create
          resources :users, only: [ :index, :create ]
          resources :payments, only: :create
          resources :refund_requests, only: [ :index, :show, :destroy ]
          resources :pending_payments, only: [ :index, :show, :update, :destroy ]
          resources :billing_lookups, only: [ :index, :show ]
          resources :remit_forms
          resources :transfers, only: [ :create ]
          #  do
          #   resources :line_items
          #   resources :payments
          #   resources :shirts
          #   resources :mailed_payments
          # end
          # resources :travelers
          # resources :line_items
          # resources :payments
          # resources :mailed_payments, only: [:index]
          # resources :remit_forms, only: [:index, :show, :update]
          #
          # get 'reports/domestic', action: :domestic, controller: :reports, as: :domestic_report
          # get 'reports/paid_in', action: :paid_in, controller: :reports, as: :paid_in_report
          # get 'reports/payments', action: :payments, controller: :reports, as: :payments_report
          # get 'reports/refunds_during/:year/:id', action: :refunds_during, controller: :reports, as: :refunds_during_report
          # get 'reports/refunds_during/:id', action: :refunds_during, controller: :reports
          # resources :reports, only: [:index, :show] do
          #   member do
          #     get :breakdown
          #   end
          # end
        end

        namespace :assignments do
          resources :recaps

          resources :responds do
            collection do
              post :reassign, defaults: { format: :json }
            end
          end

          resources :travelers do
            collection do
              post :reassign, defaults: { format: :json }
            end
          end

          root to: 'responds#index'
        end

        namespace :traveling do
          resources :event_registrations, only: [ :index, :show ]
          resources :event_results do
            resources :static_files, except: [ :index ]
          end

          namespace :flights do
            resources :airports
            resources :schedules do
              collection do
                get :air_canada
                get :srdocs
                get :virgin_australia
              end
              resources :tickets, defaults: {format: :json}
            end
            resources :tickets, defaults: {format: :html}, only: :index
          end

          resources :flights, only: :index

          resources :gcm_registrations

          namespace :ground_control do
            resources :buses do
              member do
                get :teammates, defaults: { format: :pdf }
              end

              resources :bus_travelers, defaults: {format: :json}
            end
            resources :competing_teams do
              member do
                get :teammates, defaults: { format: :pdf }
              end

              resources :team_travelers, defaults: {format: :json}
            end
            resources :hotels do
              resources :rooms, defaults: {format: :json}
            end
          end

          resources :passports, param: :user_id do
            member do
              get :eta_values
            end
          end
        end


        resources :email_files, only: %i[ index ]

        resources :credits
        resources :cleanups, only: %i[ show update ]

        resources :debits do
          collection do
            get :base
            get :insurance, defaults: { format: :csv }
          end
        end

        resources :meetings, concerns: [:versionable] do
          member do
            get :registrations
            post :registrations
          end
        end

        resources :returned_mails

        resources :fundraising_ideas do
          scope module: :fundraising_ideas do
            resources :images
          end
        end

        resources :postcards, only: :index, defaults: { format: :pdf }
        resources :statements, only: :index, defaults: { format: :pdf }
        resources :video_views, only: :index, defaults: { format: :csv }

        resources :schools
        resources :sessions, only: :index, defaults: { format: :json }

        resource  :privacy_policy, only: %i[ show create ]
        resources :terms, only: %i[ index create ]
        resources :thank_you_tickets, only: %i[ index create ]
        resources :thank_you_tickets, only: %i[ index create ], path: 'thank-you-tickets'
        resources :payments, only: :index

        resources :users do
          collection do
            get :infokits
            get :invites
            get :invitable
            get :responds
            get :download
            get :uncontacted_last_year_responds
          end

          member do
            get :addresses_available, defaults: { format: :json }
            patch :travel_preparation
            get :infokit
            post :on_the_fence
            post :selected_cancel
            post :unselected_cancel
            delete :cancel
            get :main_address
            get :travel_teams, defaults: { format: :pdf }
            resource :postcard, only: :show, defaults: { format: :pdf }
            resource :statement, only: :show, defaults: { format: :pdf } do
              member do
                get :payments, defaults: { format: :pdf }
              end
            end
            resource :transfer_expectation, only: [ :show, :update ], defaults: { format: :json }
          end

          with_auth do
            get :refund_view, defaults: { format: :html }
            post :refund_amount_email
          end

          resource :returned_mail, only: %i[ show ]

          resources :payments, only: :create do
            collection do
              post :lookup
              post :ach
            end
          end

          resources :debits, concerns: [:versionable] do
            collection do
              post :airfare
            end
          end

          resources :assignments, only: [ :index, :update ] do
            member do
              post :completed
              post :unneeded
              post :visited
            end
          end

          resource :passport do
            constraints(subdomain: /^auth(orize|enticate)(?:\.localhost|\.lvh(\.me)?|\.downundersports(\.com)?)?$/) do
              collection do
                get :get_file
                get :get_file_value
              end
            end
          end

          resource :assignment_of_benefits, only: %i[ show create ]
          resource :incentive_deadlines, only: %i[ show create destroy ]
          resource :fundraising_packet, only: %i[ show create destroy ]

          resource :legal_form, only: %i[ show create destroy ]

          resources :insurance_proofs, only: %i[ index create destroy ]
          resources :flight_proofs, only: %i[ index create destroy ]
          resources :eta_proofs, only: %i[ index create destroy ] do
            collection do
              post :extra
              delete :extra
            end
          end

          resource :avatar, only: %i[ show update destroy ]
          resources :credits, concerns: [:versionable]
          resources :offers, concerns: [:versionable]
          resources :packages, concerns: [:versionable], only: [ :index ]

          resources :ambassadors, concerns: [:versionable]
          resources :relations, concerns: [:versionable]
          resources :messages, concerns: [:versionable]
          resources :requests, concerns: [:versionable], only: [ :index ]
          resources :mailings, concerns: [:versionable]
          resources :meeting_registrations, concerns: [:versionable]
          resources :video_views, concerns: [:versionable]
        end

        resources :mailings, only: [ :show ] do
          collection do
            get :categories, defaults: { format: :json }
          end
        end

        resources :interests, only: [ :index ]

        resources :attributes, only: [ :show ], defaults: { format: :json }

        get 'version', to: 'application#version'

        get 'temp', to: 'application#temp'

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
