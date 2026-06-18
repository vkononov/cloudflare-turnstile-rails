Rails.application.routes.draw do
  root 'pages#home'

  get 'lazy-demo', to: 'pages#lazy_demo', as: :lazy_demo
  post 'lazy-demo', to: 'pages#lazy_demo'

  get 'modal-demo', to: 'pages#modal_demo', as: :modal_demo
  post 'modal-demo', to: 'pages#modal_demo'

  resource :contact, only: %i[new create]

  resources :books do
    get :new2, on: :collection
  end
end
