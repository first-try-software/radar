# frozen_string_literal: true

# Presenter for Team items in shared/_section.html.erb
# Columns: Health | Name | State | Trend | Projects | Stale | Contact
class TeamSectionItemPresenter
  def initialize(entity:, record:, view_context:, trend_direction: :stable, projects_count: 0, stale_count: 0)
    @entity = entity
    @record = record
    @view_context = view_context
    @trend_direction = trend_direction
    @projects_count = projects_count
    @stale_count = stale_count
  end

  # Health
  def health = @entity.health || :not_available
  def health_css_class = health.to_s.tr("_", "-")

  # Name
  def name = @entity.name

  # Teams don't have state
  def current_state = nil
  def state_label = "—"
  def state_css_class = "project-item-v2__state"
  def show_state? = false

  # Trend
  attr_reader :trend_direction

  def trend_arrow
    @view_context.trend_arrow_svg(trend_direction)
  end

  # Counts
  attr_reader :projects_count, :stale_count

  def stale_warning? = stale_count.positive?

  # Contact/Contact
  def owner = @entity.point_of_contact.presence || "—"

  # Navigation
  def path = @view_context.team_path(@record)
  def turbo_frame = "_top"
end
