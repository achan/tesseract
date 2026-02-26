Rails.application.routes.draw do
  mount MissionControl::Jobs::Engine, at: "/jobs"

  root "dashboard#index"
  get "dashboard/events", to: "dashboard#events", as: :dashboard_events

  resources :profiles do
    patch :toggle, on: :member
  end

  resources :workspaces, except: :show do
    resources :slack_channels, except: [:index, :new, :create] do
      patch :toggle_hidden, on: :member
      patch :toggle_actionable, on: :member
      get :events, on: :member
    end
    get "files/:file_id/proxy", to: "slack_files#show", as: :slack_file_proxy
  end

  resource :settings, only: :show
  post "logout", to: "settings#logout"

  resources :action_items, only: [:index, :new, :create, :edit, :update] do
    patch :archive, on: :member
    patch :unarchive, on: :member
  end
  resources :overviews, only: :create
  resources :live_activities, only: :destroy
  resources :slack_replies, only: :create
  resources :remote_control_sessions, only: [:create, :destroy]

  namespace :api do
    post "slack/events", to: "slack_events#create"
    post "summaries/generate", to: "summaries#generate"
    post "deploy", to: "deploys#create"

    resources :live_activities, only: [:index] do
      collection do
        post :start
        post :progress
        post :stop
      end
    end

    resources :remote_control_sessions, only: [] do
      member do
        post :started
        post :ended
      end
    end
  end

  get "up" => "rails/health#show", as: :rails_health_check
end
