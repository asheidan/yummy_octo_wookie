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
    unless valid_param?(@horizontal)
      flash[:error] = "Unknown attribute #{@horizontal.inspect}" unless @horizontal.nil?
      @horizontal = "status"
      valid_request = false
    end
    unless valid_param?(@vertical)
      flash[:error] = "Unknown attribute #{@vertical.inspect}" unless @vertical.nil?
      @vertical = "fixed_version"
      valid_request = false
    end
    unless valid_param?(@sorting)
      flash[:error] = "Unknown attribute #{@sorting.inspect}" unless @sorting.nil?
      @sorting = "priority"
      valid_request = false
    end

    unless valid_request
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

    @x_items = create_items @horizontal
    @y_items = create_items @vertical

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

  def create_items name
    items = []

    PROCS[name].call(@project).to_a.each do |x|
      items << {:id => get_id(x), :name => x.name}
    end

    unless is_value_required name then
      items << {:id => :none, :name => "None"}
    end

    if should_sort_by_name name then
      # Sort the items by name, and always put the "None" item last.
      items.sort! do |a,b|
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

    items
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

  def is_value_required item
    %w[status priority].include? item
  end

  def should_sort_by_name item
    %w[assigned_to fixed_version].include? item
  end
end
