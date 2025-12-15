Rails.application.routes.draw do
  root 'dashboard#index'

  resources :projects, only: [:index, :show, :create, :update] do
    member do
      patch :state, to: 'projects#set_state'
      patch :archive
      patch :unarchive
      post :subordinates, to: 'projects#create_subordinate'
      post 'subordinates/link', to: 'projects#link_subordinate', as: :link_subordinate
      delete 'subordinates/:child_id', to: 'projects#unlink_subordinate', as: :unlink_subordinate
      post :health_updates, to: 'projects#create_health_update'
    end
  end

  resources :teams, only: [:index, :show, :create, :update] do
    member do
      patch :archive
      post :owned_projects, to: 'teams#link_owned_project'
      post 'owned_projects/add', to: 'teams#add_owned_project', as: :add_owned_project
      post :subordinate_teams, to: 'teams#add_subordinate_team'
    end
  end

  resources :initiatives, only: [:index, :show, :create, :update] do
    member do
      patch :state, to: 'initiatives#set_state'
      patch :archive
      post :related_projects, to: 'initiatives#link_related_project'
      post 'related_projects/add', to: 'initiatives#add_related_project', as: :add_related_project
      delete 'related_projects/:project_id', to: 'initiatives#unlink_related_project', as: :unlink_related_project
    end
  end
end
