class GridsController < ApplicationController
  unloadable

  helper :queries
  include QueriesHelper

  before_filter :find_project, :authorize

  ATTRIBUTES = [
    ["Assigned", "assigned_to"],
    ["Author", "author"],
    ["Category", "category"],
    ["Priority", "priority"],
    ["Status", "status"],
    ["Version", "fixed_version"],
  ]

  PROCS = {
    "assigned_to" => proc {|project| project.members.all },
    "author" => proc {|project| User.all },
    "category" => proc {|project| IssueCategory.all },
    "priority" => proc {|project| IssuePriority.all },
    "fixed_version" => proc {|project| project.versions },
    "status" => proc {|project| IssueStatus.all },
    "area" => proc {|project|
    }
  }
  PROCS.default = proc do |project|
    puts("missing")
    []
  end

  def index
    retrieve_query

    custom_fields = IssueCustomField.where("is_for_all = ?", true)
    project_custom_fields = @project.issue_custom_fields.all

    puts (custom_fields + project_custom_fields)

    @attribute_options = ATTRIBUTES
    # @issues = @project.issues

    @attribute_options += (custom_fields + project_custom_fields).map do |field|
      [field.name, field.name.downcase]
    end

    @issues = @query.issues()

    @horizontal = params[:horizontal]
    @vertical = params[:vertical]
    @sorting = params[:sorting]

    x_getter = proc {|i|}
    y_getter = proc {|i|}

    valid_request = true

    if not valid_param?(@horizontal)
      custom_field = IssueCustomField.find_by_name(@horizontal)
      if custom_field then
        x_getter = proc {|i| i.custom_field_value(custom_field) }
      else
        flash[:error] = "Unknown attribute #{@horizontal.inspect}"
        @horizontal = "status"
        valid_request = false
      end
    end

    if not valid_param?(@vertical)
      flash[:error] = "Unknown attribute #{@vertical.inspect}"
      @vertical = "fixed_version"
      valid_request = false
    end

    if not valid_param?(@sorting)
      flash[:error] = "Unknown attribute #{@sorting.inspect}"
      @sorting = "priority"
      valid_request = false
    end

    if not valid_request
      redirect_to :controller => "grids", :action => "index", :project_id => @project, :params => {
                    :horizontal => @horizontal,
                    :vertical => @vertical,
                    :sorting => @sorting
                  }
    end


    @x_categories = PROCS[@horizontal].call(@project)
    @y_categories = PROCS[@vertical].call(@project)

    @data = Hash.new
    @data.default_proc = proc do |hash, key|
      subhash = Hash.new
      subhash.default_proc = proc do |subhash, subkey|
        subhash[subkey] = Array.new
      end
      hash[key] = subhash
    end

    @issues.each do |issue|
      y = issue[@vertical]
      y = issue.send(@vertical) if y.nil?
      #puts("#{@vertical.inspect} #{y.inspect}")
      if not @y_categories.include?(y)
        y = "Unknown"
        @y_categories += ["Unknown"]
      end

      x = issue[@horizontal]
      x = issue.send(@horizontal) if x.nil?
      #puts("#{@horizontal.inspect} #{x.inspect}")
      if not @x_categories.include?(x)
        x = "Unknown"
        @x_categories += ["Unknown"]
      end

      @data[y][x].push(issue)
    end
  end

  private

  def valid_param?(parameter)
    PROCS.has_key?(parameter) and Issue.attribute_method?(parameter)
  end

  def find_project
    @project = Project.find(params[:project_id])
  end
end
