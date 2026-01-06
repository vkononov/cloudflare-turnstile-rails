Rails.application.routes.draw do
  root 'pages#home'

  resource :contact, only: %i[new create]

  resources :books do
    get :new2, on: :collection
  end
end
