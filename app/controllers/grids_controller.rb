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
  }
  PROCS.default = proc do
    puts("missing")
    []
  end

  def index
    retrieve_query

    @attribute_options = ATTRIBUTES
    # @issues = @project.issues

    @issues = @query.issues()

    @horizontal = params[:horizontal]
    @vertical = params[:vertical]
    @sorting = params[:sorting]

    issue = Issue.new
    valid_request = true
    if not valid_param?(@horizontal)
      flash[:error] = "Unknown attribute #{@horizontal.inspect}"
      @horizontal = "status"
      valid_request = false
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


    @data = Hash.new
    @data.default_proc = proc do |hash, key|
      subhash = Hash.new
      subhash.default_proc = proc do |subhash, subkey|
        subhash[subkey] = Array.new
      end
      hash[key] = subhash
    end

    @x_categories = PROCS[@horizontal].call(@project) + [nil]
    @y_categories = PROCS[@vertical].call(@project) + [nil]

    @issues.each do |issue|
      y = issue[@vertical]
      y = issue.send(@vertical) if y.nil?
      #puts("#{@vertical.inspect} #{y.inspect}")
      if not @y_categories.include?(y)
        y = nil
      end

      x = issue[@horizontal]
      x = issue.send(@horizontal) if x.nil?
      #puts("#{@horizontal.inspect} #{x.inspect}")
      if not @x_categories.include?(x)
        x = nil
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
