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

  # For details on the DSL available within this file, see https://guides.rubyonrails.org/routing.html
end
