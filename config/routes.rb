Rails.application.routes.draw do
  root :to => 'reports#current'

  get "search" => "search#index"

  match "mcp" => "mcp#handle", via: [:post, :get, :delete]

  resources :reports, only: [:show, :index] do
    collection do
      get "current"
      post "receive_recent"
    end
  end

  resources :servers do
    member do
      post 'moveup'
      post 'movedown'
    end
  end

  get "/coverage" => redirect("#{Server::RUBYCI_LOGS_URL}/coverage-latest-html/index.html")
  get "/doxygen" => redirect("#{Server::RUBYCI_LOGS_URL}/doxygen-latest-html/index.html")

  #resources :logs, only: [:show], constraints: {id: /.*/}
end
