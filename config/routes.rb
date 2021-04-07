Rails.application.routes.draw do
  root 'users#new'
  constraints ->  request { request.session[:user_id].present? } do
    # ログインしてる時のルートパス
    root 'posts#index'
  end
  # ログインしてない時のルートパス
  root 'user_sessions#new'

  resources :users, only: %i[new create]
  get 'login', to: 'user_sessions#new'
  post 'login', to: 'user_sessions#create'
  delete 'logout', to: 'user_sessions#destroy'

  resources :users, only: %i[new create]
  resources :posts
end