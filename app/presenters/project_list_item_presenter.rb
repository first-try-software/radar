# frozen_string_literal: true

# Presenter for Project items in dashboard/_project_list_item.html.erb
# All projects rendered with: Symbol | Name | Trend | Projects | Stale | Contact | State
class ProjectListItemPresenter
  def initialize(project:, view_context:, health_override: nil)
    @project = project
    @view_context = view_context
    @health_override = health_override
    @record = ProjectRecord.find_by(name: project.name)
  end

  # Health
  def health
    return @health_override if @health_override
    return :not_available unless @project.respond_to?(:health)
    @project.health || :not_available
  end

  def health_css_class
    health.to_s.tr("_", "-")
  end

  # Name
  def name
    @project.name
  end

  # State
  def state_label
    @project.current_state.to_s.tr("_", " ").titleize
  end

  def state_css_class
    "project-item-v2__state project-item-v2__state--#{@project.current_state}"
  end

  # Contact
  def contact
    @project.respond_to?(:point_of_contact) ? (@project.point_of_contact.presence || "—") : "—"
  end

  # Navigation
  def path
    @view_context.project_path(@record)
  end

  # Trend
  def trend_direction
    @trend_direction ||= @project.respond_to?(:trend) ? @project.trend : :stable
  end

  def trend_arrow
    @view_context.trend_arrow_svg(trend_direction)
  end

  # Projects count (children)
  def projects_count
    @projects_count ||= active_children.size
  end

  # Stale count
  def stale_count
    @stale_count ||= calculate_stale_count
  end

  private

  def children
    @children ||= @project.respond_to?(:children) ? @project.children : []
  end

  def active_children
    @active_children ||= children.reject { |c| c.respond_to?(:archived?) && c.archived? }
  end

  def calculate_stale_count
    stale_children = active_children.select do |child|
      next false unless [:in_progress, :blocked].include?(child.current_state)

      # Get the effective latest update (child's own if leaf, or from its descendants)
      if child.respond_to?(:leaf?) && child.leaf?
        latest = child.latest_health_update
      else
        # For child parents, find most recent update from their leaf descendants
        leaves = child.respond_to?(:leaf_descendants) ? child.leaf_descendants : []
        latest = leaves.map(&:latest_health_update).compact.max_by { |u| u.date.to_date }
      end
      latest.nil? || (Date.current - latest.date.to_date).to_i > 7
    end
    stale_children.size
  end
end
