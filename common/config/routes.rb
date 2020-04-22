Common::Engine.routes.draw do
  mount ActionCable.server => '/cable'

  concern :versionable do
    get 'version/:version', action: :version, on: :collection
  end

  post '/rails/active_storage/direct_uploads/assignment_of_benefits/:id' => 'api/direct_uploads#assignment_of_benefits'
  post '/rails/active_storage/direct_uploads/legal_form/:id'             => 'api/direct_uploads#legal_form'
  post '/rails/active_storage/direct_uploads/passport/:id'               => 'api/direct_uploads#passport'
  post '/rails/active_storage/direct_uploads'                            => 'application#not_authorized'

  get 'statement/:dus_id_hash', to: 'statements#show', defaults: {format: :pdf}, constraints: ->(request) do
    request.params[:dus_id_hash].size == 64
  end

  get 'version', to: 'application#version'

  get '*path', to: "application#serve_asset", constraints: ->(request) do
    !request.xhr? && (!request.format.html? || (request.path =~ /\![A-Za-z]{3,5}/)) && (request.path !~ /active_storage/)
  end

  get '*path', to: "application#fallback_index_html", constraints: ->(request) do
    !request.xhr? && request.format.html?
  end
end
