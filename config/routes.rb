Rails.application.routes.draw do
  # Define your application routes per the DSL in https://guides.rubyonrails.org/routing.html

  # Reveal health status on /up that returns 200 if the app boots with no exceptions, otherwise 500.
  # Can be used by load balancers and uptime monitors to verify that the app is live.
  get "up" => "rails/health#show", as: :rails_health_check

  # Render dynamic PWA files from app/views/pwa/* (remember to link manifest in application.html.erb)
  # get "manifest" => "rails/pwa#manifest", as: :pwa_manifest
  # get "service-worker" => "rails/pwa#service_worker", as: :pwa_service_worker

resources :users, only: %i[index new create edit update]
resources :users, only: [] do
  resources :avatar_assets, only: :create, module: :users
end

post "global_assets/presign", to: "global_asset_uploads#create", as: :global_assets_presign

  resources :events do
    resource :settings, only: [:show], module: :events, controller: :settings do
      get :clients
      get :vendors
      get :locations
      get :planners
    end

    resource :people, only: :show, module: :events

    resources :event_photo_documents, only: :create, module: :events

    resources :payments, module: :events
    resources :approvals, module: :events

    resources :calendars, only: :index, module: :events, controller: :calendars

    resource :calendar, only: %i[show update], module: :events do
      get :grid, to: "calendar_grids#show"
      patch "grid/items/:item_id", to: "calendar_grids#update", as: :grid_item
      patch "grid/bulk", to: "calendar_grids#bulk_update", as: :grid_bulk
      resources :items,
                controller: "calendar_items",
                except: :index do
        member do
          patch :mark_completed
          patch :mark_planned
          patch :remove_milestone_tag
        end
      end
      resources :tags,
                only: %i[create update destroy],
                controller: "calendar_tags"
      resources :views,
                controller: "calendar_views",
                except: :index do
        member do
          get :grid, to: "calendar_grids#show"
          patch "grid/items/:item_id", to: "calendar_grids#update", as: :grid_item
          patch "grid/bulk", to: "calendar_grids#bulk_update", as: :grid_bulk
        end
      end
    end

    resources :event_links, only: %i[create update destroy], module: :events do
      member do
        patch :move_up
        patch :move_down
      end
    end

    resources :event_vendors, only: %i[create update destroy], module: :events do
      member do
        patch :move_up
        patch :move_down
      end
    end

    resources :event_venues, only: %i[create update destroy], module: :events do
      member do
        patch :move_up
        patch :move_down
      end
    end

    resources :team_members, only: %i[create update destroy], module: :events do
      member { post :issue_reset }
    end

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

    namespace :documents do
      resources :generated, param: :logical_id, controller: :generated do
        member do
          post :compile
          post :duplicate
          post :mark_template
          delete :unmark_template
        end
        collection do
          post :create_from_template
        end

        resources :builds,
                  controller: "generated/builds",
                  only: [:destroy] do
          member do
            patch :cancel
          end
        end

        resources :segments,
                  controller: "generated/segments",
                  only: %i[create update destroy] do
          collection do
            patch :reorder
          end

          member do
            post :render_pdf
            get :preview
            get :cached_pdf
          end
        end
      end

      resources :templates, only: :index, controller: "templates"
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
    get "login", to: "sessions#new"
    post "login", to: "sessions#create"
    match "logout", to: "sessions#destroy", via: %i[delete get]

    get "reset/:token", to: "password_resets#show", as: :password_reset
    patch "reset/:token", to: "password_resets#update"
    put "reset/:token", to: "password_resets#update"

    resources :events, only: :show do
      resources :calendars, only: %i[index show], param: :slug
      resources :decision_calendar_items, only: %i[show update]
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
      resources :designs, only: %i[index create]
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
