Rails.application.routes.draw do
  root "dashboard#index"

  resources :workspaces, except: :show do
    resources :slack_channels, except: [:index, :new, :create] do
      patch :toggle_hidden, on: :member
    end
  end

  resource :settings, only: :show

  resources :action_items, only: :update

  namespace :api do
    post "slack/events", to: "slack_events#create"
    post "summaries/generate", to: "summaries#generate"
  end

  get "up" => "rails/health#show", as: :rails_health_check
end
