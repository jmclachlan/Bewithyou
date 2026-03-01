Rails.application.routes.draw do
  get "up" => "rails/health#show", as: :rails_health_check

  get "/g/:token", to: "watch#show"
  post "/webhooks/mux", to: "webhooks/mux#create"
end
