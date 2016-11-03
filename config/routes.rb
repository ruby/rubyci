Rails.application.routes.draw do
  get 'logs/show'

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
    resources :logs, only: [:show]
  end
end
