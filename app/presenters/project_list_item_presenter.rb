# frozen_string_literal: true

# Presenter for Project items in dashboard/_project_list_item.html.erb
# All projects rendered with: Symbol | Name | Trend | Projects | Stale | Contact | State
class ProjectListItemPresenter
  def initialize(project:, view_context:, health_override: nil)
    @project = project
    @view_context = view_context
    @health_override = health_override
  end

  # Health
  def health
    return @health_override if @health_override

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
    @project.point_of_contact.presence || "—"
  end

  # Navigation
  def path
    @view_context.project_path(@project.id)
  end

  # Trend
  def trend_direction
    @trend_direction ||= trend_service_result[:trend_direction]
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

  def trend_service_result
    @trend_service_result ||= ProjectTrendService.new(
      project: @project,
      health_update_repository: health_update_repository,
      current_date: Date.current
    ).call
  end

  def health_update_repository
    Rails.application.config.x.health_update_repository
  end

  def children
    @children ||= @project.children
  end

  def active_children
    @active_children ||= children.reject(&:archived?)
  end

  def calculate_stale_count
    stale_children = active_children.select do |child|
      next false unless [:in_progress, :blocked].include?(child.current_state)

      # Get the effective latest update (child's own if leaf, or from its descendants)
      if child.leaf?
        latest = child.latest_health_update
      else
        # For child parents, find most recent update from their leaf descendants
        leaves = child.leaf_descendants
        latest = leaves.map(&:latest_health_update).compact.max_by { |u| u.date.to_date }
      end
      latest.nil? || (Date.current - latest.date.to_date).to_i > 7
    end
    stale_children.size
  end
end
