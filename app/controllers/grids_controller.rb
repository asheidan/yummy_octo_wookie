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

  def index
    retrieve_query

    @attribute_options = get_attribute_options
    @procs = PROCS.clone
    @issues = @query.issues()
    @horizontal = params[:horizontal]
    @vertical = params[:vertical]
    @sorting = params[:sorting]
    @custom_field_values = {}

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
      # The important point here is to get the ID of x and y
      y = issue[@vertical]
      y = issue.send(@vertical) if y.nil?
      if @horizontal.start_with? "custom_field-"
        # This is a custom field
        id = @horizontal.sub("custom_field-", "").to_i
        value = get_custom_field_value issue, id
        x = @custom_field_values[id][value] unless value.nil?
      else
        x = issue[@horizontal]
        x = issue.send(@horizontal) if x.nil?
      end
      @data[get_id y][get_id x].push(issue)
    end
  end

  private

  def valid_param? name
    (@procs.has_key? name and Issue.attribute_method? name) or name.start_with? "custom_field-"
  end

  def find_project
    @project = Project.find(params[:project_id])
  end

  def create_items name
    items = []

    if @procs.has_key? name
      @procs[name].call(@project).to_a.each do |x|
        items << {:id => get_id(x), :name => x.name}
      end
    elsif name.start_with? "custom_field-"
      # This is a custom field
      id = name.sub("custom_field-", "").to_i
      @custom_field_values[id] = get_custom_field_values id
      @custom_field_values[id].each do |value, value_id|
        items << {:id => value_id, :name => value}
      end
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
    when Fixnum
      entity
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

  def get_attribute_options
    attribute_options = ATTRIBUTES.clone
    @project.all_issue_custom_fields.each do |custom_field|
      attribute_options << [custom_field[:name], "custom_field-#{custom_field[:id]}"]
    end
    attribute_options
  end

  def get_custom_field_values id
    values = {}
    value_id = 1
    @issues.each do |issue|
      value = get_custom_field_value issue, id
      values[value] = value_id unless (value.nil? or value.empty? or values.has_key? value)
      value_id += 1
    end
    values
  end

  def get_custom_field_value issue, id
    issue.custom_field_values.each do |custom_field_value|
      if custom_field_value.custom_field_id == id
        return custom_field_value.to_s
      end
    end
    nil
  end
end
