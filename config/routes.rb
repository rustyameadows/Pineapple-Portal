Rails.application.routes.draw do
  # Define your application routes per the DSL in https://guides.rubyonrails.org/routing.html

  # Reveal health status on /up that returns 200 if the app boots with no exceptions, otherwise 500.
  # Can be used by load balancers and uptime monitors to verify that the app is live.
  get "up" => "rails/health#show", as: :rails_health_check

  # Render dynamic PWA files from app/views/pwa/* (remember to link manifest in application.html.erb)
  # get "manifest" => "rails/pwa#manifest", as: :pwa_manifest
  # get "service-worker" => "rails/pwa#service_worker", as: :pwa_service_worker

  resources :users, only: %i[new create]

  resources :events do
    resources :questionnaires do
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

  get "/questionnaire_templates", to: "questionnaires#templates", as: :questionnaire_templates
  resources :attachments, only: %i[create destroy]

  get "/login", to: "sessions#new"
  post "/login", to: "sessions#create"
  delete "/logout", to: "sessions#destroy"

  # Defines the root path route ("/")
  root "welcome#home"
end
