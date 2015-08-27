module GridsHelper
  include Redmine::I18n

  def grids_context_menu(url)
    unless @context_menu_included
      content_for :header_tags do
        javascript_include_tag('context_menu') +
          stylesheet_link_tag('context_menu')
      end
      if l(:direction) == 'rtl'
        content_for :header_tags do
          stylesheet_link_tag('context_menu_rtl')
        end
      end
      @context_menu_included = true
    end
    #javascript_tag "contextMenuInit('#{ url_for(url) }')"
    ""
  end
end
