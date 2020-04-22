Rails.application.routes.draw do
  root "admin/application#fallback_index_html"

  mount ActionCable.server => '/cable'

  get '/clear_logs' => 'application#clear_logs'

  concern :versionable do
    get 'version/:version', action: :version, on: :collection
  end

  get '/admin/invitations' => 'admin/invitations#index'
  post '/admin/invitations' => 'admin/invitations#index'

  get '/admin/invitations/infokit' => 'admin/invitations#infokit'
  post '/admin/invitations/infokit' => 'admin/invitations#infokit'

  extend AusRoutes
  extend AdminRoutes
  extend APIRoutes


  post '/rails/active_storage/direct_uploads'                            => 'admin/direct_uploads#create'
  post '/rails/active_storage/direct_uploads/assignment_of_benefits/:id' => 'admin/direct_uploads#assignment_of_benefits'
  post '/rails/active_storage/direct_uploads/eta_proofs/:id'             => 'admin/direct_uploads#eta_proofs'
  post '/rails/active_storage/direct_uploads/event_result/:event_id/static_files(/:id)' => 'admin/direct_uploads#event_result'
  post '/rails/active_storage/direct_uploads/insurance_proofs/:id'       => 'admin/direct_uploads#insurance_proofs'
  post '/rails/active_storage/direct_uploads/flight_proofs/:id'       => 'admin/direct_uploads#flight_proofs'
  post '/rails/active_storage/direct_uploads/legal_form/:id'             => 'admin/direct_uploads#legal_form'
  post '/rails/active_storage/direct_uploads/passport/:id'               => 'admin/direct_uploads#passport'
  post '/rails/active_storage/direct_uploads/incentive_deadlines/:id'    => 'admin/direct_uploads#incentive_deadlines'
  post '/rails/active_storage/direct_uploads/fundraising_packet/:id'     => 'admin/direct_uploads#fundraising_packet'

  get 'no_op', to: 'admin/application#no_op'
  get 'version', to: 'application#version'

  get '*path', to: "admin/application#serve_asset", constraints: ->(request) do
    !request.xhr? && (!request.format.html? || (request.path =~ /\![A-Za-z]{3,5}/)) && (request.path !~ /active_storage/)
  end

  get '*path', to: redirect(status: 303) {|params, req| "/admin/#{params[:path]}"}, constraints: ->(request) do
    (request.headers['REQUEST_PATH'].to_s !~ /^\/?(admin|aus)/) &&
    !request.xhr? &&
    request.format.html?
  end

  get '*path', to: "admin/application#fallback_index_html", constraints: ->(request) do
    !request.xhr? && request.format.html?
  end
end
