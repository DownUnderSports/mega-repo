Rails.application.routes.draw do
  root "application#fallback_index_html"

  mount ActionCable.server => '/cable'

  get '/clear_logs' => 'application#clear_logs'

  concern :versionable do
    get 'version/:version', action: :version, on: :collection
  end

  if Rails.env.production?
    get '*path', to: redirect(status: 307) {|params, req| "#{params[:path]}".sub(/admin\/?/, '')}, constraints: ->(request) do
      request.headers['REQUEST_PATH'].to_s =~ /admin/
    end
  end

  extend TravelRoutes
  extend APIRoutes

  get 'no_op', to: 'application#no_op'

  post '/rails/active_storage/direct_uploads/assignment_of_benefits/:id' => 'api/direct_uploads#assignment_of_benefits'
  post '/rails/active_storage/direct_uploads/legal_form/:id'             => 'api/direct_uploads#legal_form'
  post '/rails/active_storage/direct_uploads/passport/:id'               => 'api/direct_uploads#passport'
  post '/rails/active_storage/direct_uploads'                            => 'application#user_not_authorized'

  get 'statement/:dus_id_hash', to: 'statements#show', defaults: {format: :pdf}, constraints: ->(request) do
    request.params[:dus_id_hash].size == 64
  end

  get 'version', to: 'application#version'

  get 'payment/:id', to: redirect('https://legacy.downundersports.com/payment/%{id}', status: 303), constraints: { id: /([A-Za-z0-9]{4}-?){3}/ }

  get 'payments/:id', to: 'application#fallback_index_html'

  get 'sports-programs/*path', to: redirect('https://s3-us-west-1.amazonaws.com/downundersports-2019-production/sports-programs/%{path}.%{format}', status: 303)

  get '*path', to: "application#serve_asset", constraints: ->(request) do
    !request.xhr? && (!request.format.html? || (request.path =~ /\![A-Za-z]{3,5}/)) && (request.path !~ /active_storage/)
  end

  get '*path', to: "application#fallback_index_html", constraints: ->(request) do
    !request.xhr? && request.format.html?
  end
end
