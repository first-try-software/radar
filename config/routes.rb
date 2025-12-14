Rails.application.routes.draw do
  root 'projects#index'

  resources :projects, only: [:index, :show, :create, :update] do
    member do
      patch :state, to: 'projects#set_state'
      patch :archive
      post :subordinates, to: 'projects#create_subordinate'
      post :health_updates, to: 'projects#create_health_update'
    end
  end

  resources :initiatives, only: [:index, :show, :create, :update] do
    member do
      patch :archive
      post :related_projects, to: 'initiatives#create_related_project'
    end
  end
end
