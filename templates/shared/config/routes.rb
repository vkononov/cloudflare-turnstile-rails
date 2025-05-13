Rails.application.routes.draw do
  root 'pages#home'

  resources :books do
    get :new2, on: :collection
  end
end
