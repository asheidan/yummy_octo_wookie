class GridsController < ApplicationController
  unloadable

  helper :queries
  include QueriesHelper

  before_filter :find_project, :authorize

  ATTRIBUTES = [
    ["Assigned", "assigned_to"],
    ["Category", "category"],
    ["Priority", "priority"],
    ["Status", "status"],
    ["Version", "fixed_version"],
  ]

  PROCS = {
    "assigned_to" => proc {|project| project.members.all },
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
      flash[:error] = "Unknown attribute #{@horizontal.inspect}" unless @horizontal.nil?
      @horizontal = "status"
      valid_request = false
    end
    if not valid_param?(@vertical)
      flash[:error] = "Unknown attribute #{@vertical.inspect}" unless @vertical.nil?
      @vertical = "fixed_version"
      valid_request = false
    end
    if not valid_param?(@sorting)
      flash[:error] = "Unknown attribute #{@sorting.inspect}" unless @sorting.nil?
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

    @x_categories = create_categories @horizontal
    @y_categories = create_categories @vertical

    @issues.each do |issue|
      y = issue[@vertical]
      y = issue.send(@vertical) if y.nil?
      #puts("#{@vertical.inspect} #{y.inspect}")

      x = issue[@horizontal]
      x = issue.send(@horizontal) if x.nil?
      #puts("#{@horizontal.inspect} #{x.inspect}")
      @data[get_id y][get_id x].push(issue)
    end
  end

  private

  def valid_param?(parameter)
    PROCS.has_key?(parameter) and Issue.attribute_method?(parameter)
  end

  def find_project
    @project = Project.find(params[:project_id])
  end

  def create_categories parameter
    categories = []

    items = PROCS[parameter].call(@project).to_a
    unless value_required parameter then
      items << nil
    end

    items.each do |x|
      categories << if x.nil? then{:id => :none, :name => "None"} else {:id => get_id(x), :name => x.name} end
    end

    if sort_by_name parameter then
      # Sort the categories by name, and always put the "None" category last.
      categories.sort! do |a,b|
        if a[:id] != :none and b[:id] == :none then
          -1
        elsif a[:id] == :none and b[:id] != :none then
          1
        elsif a[:id] == :none and b[:id] == :none then
          0
        elsif a[:name] < b[:name] then
          -1
        elsif a[:name] > b[:name] then
          1
        else
          0
        end
      end
    end

    categories
  end

  def get_id entity
    case entity
    when nil
      :none
    when Member
      entity.user_id
    else
      entity.id
    end
  end

  def value_required category
    %w[status priority].include? category
  end

  def sort_by_name category
    %w[assigned_to fixed_version].include? category
  end
end
