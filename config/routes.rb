Rails.application.routes.draw do
  root :to => 'reports#current'

  resources :reports do
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

  get "/coverage" => redirect("https://rubyci.s3.amazonaws.com/debian9-coverage/ruby-trunk/lcov/index.html")

  resources :logs, only: [:show], constraints: {id: /.*/}
end
