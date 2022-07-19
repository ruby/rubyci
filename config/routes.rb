Rails.application.routes.draw do
  root :to => 'reports#current'

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

  get "/coverage" => redirect("https://rubyci.s3.amazonaws.com/coverage-latest-html/index.html")
  get "/doxygen" => redirect("https://rubyci.s3.amazonaws.com/doxygen-latest-html/index.html")

  #resources :logs, only: [:show], constraints: {id: /.*/}
end
