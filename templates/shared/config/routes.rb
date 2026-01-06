Rails.application.routes.draw do
  root 'pages#home'

  get  'contact', to: 'pages#contact'
  post 'contact', to: 'pages#submit_contact'

  resources :books do
    get :new2, on: :collection
  end
end
