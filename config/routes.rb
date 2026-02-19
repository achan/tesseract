Rails.application.routes.draw do
  root "dashboard#index"

  resources :workspaces, except: :show do
    resources :slack_channels, except: [:index, :new, :create] do
      patch :toggle_hidden, on: :member
    end
    get "files/:file_id/proxy", to: "slack_files#show", as: :slack_file_proxy
  end

  resource :settings, only: :show
  post "logout", to: "settings#logout"

  resources :action_items, only: :update
  resources :live_activities, only: :destroy
  resources :slack_replies, only: :create

  namespace :api do
    post "slack/events", to: "slack_events#create"
    post "summaries/generate", to: "summaries#generate"

    resources :live_activities, only: [:index] do
      collection do
        post :start
        post :progress
        post :stop
      end
    end
  end

  get "up" => "rails/health#show", as: :rails_health_check
end
