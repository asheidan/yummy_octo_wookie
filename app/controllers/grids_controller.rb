class GridsController < ApplicationController
  unloadable

  # helper :queries
  # include QueriesHelper

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
    # retrieve_query

    @attribute_options = ATTRIBUTES
    @issues = @project.issues

    @horizontal = params[:horizontal]
    @vertical = params[:vertical]
    @sorting = params[:sorting]

    issue = Issue.new
    if @horizontal.nil? or not (issue.has_attribute?(@horizontal) or issue.respond_to?(@horizontal))
      @horizontal = "status"
    end
    if @vertical.nil? or not (issue.has_attribute?(@vertical) or issue.respond_to?(@vertical))
      @vertical = "fixed_version"
    end
    if @sorting.nil? or not (issue.has_attribute?(@sorting) or issue.respond_to?(@sorting))
      @sorting = "priority"
    end


    @data = Hash.new
    @data.default_proc = proc do |hash, key|
      subhash = Hash.new
      subhash.default_proc = proc do |subhash, subkey|
        subhash[subkey] = Array.new
      end
      hash[key] = subhash
    end

    @x_categories = PROCS[@horizontal].call(@project) + ["Unknown"]
    @y_categories = PROCS[@vertical].call(@project) + ["Unknown"]

    @issues.each do |issue|
      y = issue[@vertical]
      y = issue.send(@vertical) if y.nil?
      #puts("#{@vertical.inspect} #{y.inspect}")
      if not @y_categories.include?(y)
        y = "Unknown"
      end

      x = issue[@horizontal]
      x = issue.send(@horizontal) if x.nil?
      #puts("#{@horizontal.inspect} #{x.inspect}")
      if not @x_categories.include?(x)
        x = "Unknown"
      end

      @data[y][x].push(issue)
    end
  end

  private

  def find_project
    @project = Project.find(params[:project_id])
  end
end
