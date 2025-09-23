Rails.application.routes.draw do
  # Define your application routes per the DSL in https://guides.rubyonrails.org/routing.html

  # Reveal health status on /up that returns 200 if the app boots with no exceptions, otherwise 500.
  # Can be used by load balancers and uptime monitors to verify that the app is live.
  get "up" => "rails/health#show", as: :rails_health_check

  # Render dynamic PWA files from app/views/pwa/* (remember to link manifest in application.html.erb)
  # get "manifest" => "rails/pwa#manifest", as: :pwa_manifest
  # get "service-worker" => "rails/pwa#service_worker", as: :pwa_service_worker

  resources :users, only: %i[index new create edit update]

  resources :events do
    resource :settings, only: :show, module: :events do
    end

    resources :payments, module: :events
    resources :approvals, module: :events

    resource :calendar, only: %i[show update], module: :events do
      resources :items,
                controller: "calendar_items",
                except: :index
      resources :tags,
                only: %i[create update destroy],
                controller: "calendar_tags"
      resources :views,
                controller: "calendar_views",
                except: :index
    end

    resources :event_links, only: %i[create update destroy], module: :events do
      member do
        patch :move_up
        patch :move_down
      end
    end

    resources :team_members, only: %i[create update destroy], module: :events

    resources :questionnaires do
      member do
        patch :mark_finished
        patch :mark_in_progress
      end
      resources :sections, controller: "questionnaire_sections", only: %i[create update destroy] do
        collection { patch :reorder }
      end
      resources :questions, only: %i[new create edit update destroy] do
        member { patch :answer }
        collection { patch :reorder }
      end
    end

    resources :documents do
      collection do
        get :packets
        get :staff_uploads
        get :client_uploads
      end
      collection { post :presign, to: "document_uploads#create" }
      member { get :download }
    end
  end

  namespace :client, path: "portal" do
    resources :events, only: :show do
      resource :decision_calendar, only: :show, controller: :decision_calendars
      resources :calendars, only: %i[index show], param: :slug
      resource :guest_list, only: :show, controller: :guest_lists
      resources :questionnaires, only: %i[index show] do
        member do
          patch :mark_finished
          patch :mark_in_progress
        end
        resources :questions, only: [] do
          patch :answer, to: "question_answers#update"
        end
      end
      resources :designs, only: :index
      resources :financials, only: :index
      resources :payments, only: :show do
        member do
          patch :mark_paid, to: "payments#mark_paid"
        end
      end
    end
  end

  get "/questionnaire_templates", to: "questionnaires#templates", as: :questionnaire_templates
  get "/settings", to: "settings#show", as: :settings
  resources :attachments, only: %i[create destroy]

  get "/login", to: "sessions#new"
  post "/login", to: "sessions#create"
  delete "/logout", to: "sessions#destroy"

  # Defines the root path route ("/")
  root "welcome#home"
end
