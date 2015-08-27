# Plugin's routes
# See: http://guides.rubyonrails.org/routing.html

match 'projects/:project_id/grids', :to => 'grids#index', :via => [:get, :post]
