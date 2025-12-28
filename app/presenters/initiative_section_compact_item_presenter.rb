# frozen_string_literal: true

# Presenter for Initiative items in shared/_section_compact.html.erb
# Columns: Health | Name | Trend | Projects | Stale
class InitiativeSectionCompactItemPresenter
  def initialize(entity:, view_context:, trend_direction: :stable, projects_count: 0, stale_count: 0)
    @entity = entity
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

  # Trend
  attr_reader :trend_direction

  def trend_arrow
    @view_context.trend_arrow_svg(trend_direction)
  end

  # Counts
  attr_reader :projects_count, :stale_count

  def stale_warning? = stale_count.positive?

  # Navigation
  def path = @view_context.initiative_path(@entity.id)
  def turbo_frame = "_top"
end
