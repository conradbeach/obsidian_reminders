Rails.application.routes.draw do
  resource :session
  resource :push_subscription, only: [:create, :destroy]
  resources :reminders, only: [:index, :create] do
    resource :completion, only: [:create, :destroy], module: :reminders
  end
  resource :settings, only: [:show, :update]
  resource :guide, only: :show
  resource :reminder_filter, only: :update
  resource :api_token, only: :create
  resource :test_notification, only: :create
  mount MissionControl::Jobs::Engine, at: "/jobs"

  # Reveal health status on /up that returns 200 if the app boots with no exceptions, otherwise 500.
  # Can be used by load balancers and uptime monitors to verify that the app is live.
  get "up" => "rails/health#show", as: :rails_health_check

  get "manifest" => "rails/pwa#manifest", as: :pwa_manifest
  get "service-worker" => "rails/pwa#service_worker", as: :pwa_service_worker

  root "reminders#index"
end
