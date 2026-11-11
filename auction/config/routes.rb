Rails.application.routes.draw do
  # Define your application routes per the DSL in https://guides.rubyonrails.org/routing.html

  # Reveal health status on /up that returns 200 if the app boots with no exceptions, otherwise 500.
  # Can be used by load balancers and uptime monitors to verify that the app is live.
  get "up" => "rails/health#show", as: :rails_health_check

  # Render dynamic PWA files from app/views/pwa/* (remember to link manifest in application.html.erb)
  # get "manifest" => "rails/pwa#manifest", as: :pwa_manifest
  # get "service-worker" => "rails/pwa#service_worker", as: :pwa_service_worker

  # Defines the root path route ("/")
  root "home#index"

  resources :auctions, only: %i[index show] do
    resources :bids, only: :create
  end
  resources :events, only: :new
  resources :products, only: %i[new create destroy] do
    resources :product_images, only: %i[create destroy] do
      patch :reorder, on: :collection
    end
    resources :product_documents, only: %i[create destroy]
    member do
      get   "steps/:step", to: "products#step",        as: :step,        constraints: { step: /[1-4]/ }
      patch "steps/:step", to: "products#update_step", as: :update_step, constraints: { step: /[1-4]/ }
    end
  end
  namespace :admin do
    resources :products, only: %i[index show] do
      member do
        patch :approve
        patch :reject
      end
    end
  end
  get "my/events",   to: "events#index",   as: :my_events
  get "my/products", to: "products#index", as: :my_products
  get    "login",    to: "sessions#new",          as: :login
  post   "login",    to: "sessions#create"
  delete "logout",   to: "sessions#destroy",      as: :logout
  get  "onboarding",       to: "onboarding#index",  as: :onboarding
  post "onboarding/otp",        to: "onboarding#send_otp",   as: :onboarding_otp
  post "onboarding/otp/verify", to: "onboarding#verify_otp", as: :verify_onboarding_otp
  get  "onboarding/:step", to: "onboarding#show",   as: :onboarding_step, constraints: { step: /[1-4]/ }
  post "onboarding/:step", to: "onboarding#update", constraints: { step: /[1-4]/ }
  get    "register", to: "registrations#new",     as: :register
  post   "register", to: "registrations#create"
  get "design",   to: "design#index"
end
