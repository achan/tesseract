Rails.application.routes.draw do
  root "dashboard#index"

  resources :workspaces, except: :show do
    resources :slack_channels do
      get :available, on: :collection
    end
  end

  resource :settings, only: :show do
    post :refresh_slack_cache, on: :member
  end

  resources :action_items, only: :update

  namespace :api do
    post "slack/events", to: "slack_events#create"
    post "summaries/generate", to: "summaries#generate"
  end

  get "up" => "rails/health#show", as: :rails_health_check
end
