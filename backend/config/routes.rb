Rails.application.routes.draw do
  # Define your application routes per the DSL in https://guides.rubyonrails.org/routing.html

  # Reveal health status on /up that returns 200 if the app boots with no exceptions, otherwise 500.
  # Can be used by load balancers and uptime monitors to verify that the app is live.
  get "up" => "rails/health#show", as: :rails_health_check

  # Defines the root path route ("/")
  # root "posts#index"

  # Rota do ActionCable (WebSocket)
  mount ActionCable.server => '/cable'

  # Rota de login: o frontend vai enviar um POST para /sessions com { name: "Fulano" }
  post '/sessions', to: 'sessions#create'

  # Rotas de Rooms (PRECISAM de autenticação JWT)
  resources :rooms, only: [:index, :show, :create, :destroy] do
    member do
      patch :close # PATCH /rooms/:id/close
    end
    resources :messages, only: [:index, :create]
  end
end
