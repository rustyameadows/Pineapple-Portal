Rails.application.routes.draw do
  # Define your application routes per the DSL in https://guides.rubyonrails.org/routing.html

  # Reveal health status on /up that returns 200 if the app boots with no exceptions, otherwise 500.
  # Can be used by load balancers and uptime monitors to verify that the app is live.
  get "up" => "rails/health#show", as: :rails_health_check

  # Render dynamic PWA files from app/views/pwa/* (remember to link manifest in application.html.erb)
  # get "manifest" => "rails/pwa#manifest", as: :pwa_manifest
  # get "service-worker" => "rails/pwa#service_worker", as: :pwa_service_worker

  resources :users, only: %i[index new create]

  resources :events do
    resource :settings, only: :show, module: :events do
      get :team
      get :notifications
    end

    resources :event_links, only: %i[create update destroy], module: :events do
      member do
        patch :move_up
        patch :move_down
      end
    end

    resources :questionnaires do
      resources :sections, controller: "questionnaire_sections", only: %i[create update destroy] do
        collection { patch :reorder }
      end
      resources :questions, only: %i[new create edit update destroy] do
        member { patch :answer }
        collection { patch :reorder }
      end
    end

    resources :documents do
      collection { post :presign, to: "document_uploads#create" }
      member { get :download }
    end
  end

  namespace :client, path: "portal" do
    resources :events, only: :show do
      resource :decision_calendar, only: :show, controller: :decision_calendars
      resource :guest_list, only: :show, controller: :guest_lists
      resources :questionnaires, only: %i[index show] do
        resources :questions, only: [] do
          patch :answer, to: "question_answers#update"
        end
      end
      resources :designs, only: :index
      resources :financials, only: :index
    end
  end

  get "/questionnaire_templates", to: "questionnaires#templates", as: :questionnaire_templates
  resources :attachments, only: %i[create destroy]

  get "/login", to: "sessions#new"
  post "/login", to: "sessions#create"
  delete "/logout", to: "sessions#destroy"

  # Defines the root path route ("/")
  root "welcome#home"
end
