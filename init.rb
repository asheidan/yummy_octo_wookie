Redmine::Plugin.register :yummy_octo_wookie do
  name 'Yummy Octo Wookie plugin'
  author 'Emil Eriksson'
  description 'This is a plugin for Redmine'
  version '0.0.1'
  url 'http://example.com/path/to/plugin'
  author_url 'http://example.com/about'

  project_module :grids do
    permission :view_grids, :grids => :index
  end

  menu :project_menu, :grids, { :controller => 'grids', :action => 'index' }, :caption => 'Grids', :after => :activity, :param => :project_id
end
