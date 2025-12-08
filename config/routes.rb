Rails.application.routes.draw do
  resources :projects, only: [:show, :create, :update] do
    member do
      patch :state, to: 'projects#set_state'
      patch :archive
      post :subordinates, to: 'projects#create_subordinate'
    end
  end
end
