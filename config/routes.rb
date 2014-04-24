LytitServer::Application.routes.draw do
  mount RailsAdmin::Engine => '/admin', :as => 'rails_admin'

  namespace :api, :defaults => {:format => 'json'}  do
    namespace :v1 do
      resources :users, only: :create do
        get '/posts', :action => :get_comments
      end
      resources :sessions, only: :create
      resources :venues, only: [:index, :show] do
        resources :venue_ratings, only: [:create]
        get '/posts', :action => :get_comments
      end

      controller :venues, :defaults => {:format => 'json'} do
        post '/venues/addComment', :action => :add_comment
      end
    end
  end

  controller :system, :defaults => {:format => 'json'}  do
    get 'system/status', :action => 'status', :as => :system_status
  end

  #TODO will change this later if got any thing to show on home page!
  root :to => 'system#status'
end
