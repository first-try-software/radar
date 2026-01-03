require_relative 'project_attributes'
require_relative 'project_loaders'
require_relative 'project_health'
require_relative 'project_hierarchy'

class Project
  ALLOWED_STATES = [:new, :todo, :in_progress, :blocked, :on_hold, :done].freeze
  STATE_PRIORITY = [:blocked, :in_progress, :on_hold, :todo, :new, :done].freeze
  ACTIVE_STATES = [:in_progress, :blocked].freeze

  def initialize(attributes:, loaders: ProjectLoaders.new)
    @attributes = attributes
    @loaders = loaders
  end

  def id = attributes.id
  def name = attributes.name
  def description = attributes.description
  def point_of_contact = attributes.point_of_contact
  def archived? = attributes.archived?

  def valid?
    attributes.name_valid? && state_valid?
  end

  def errors
    errors = attributes.name_errors
    errors << 'state must be valid' unless state_valid?
    errors
  end

  def children = hierarchy.children
  def parent = hierarchy.parent
  def leaf? = hierarchy.leaf?
  def leaf_descendants = hierarchy.leaf_descendants
  alias_method :subordinate_projects, :children

  def owning_team
    @owning_team ||= loaders.owning_team&.call(self)
  end

  def effective_contact
    return point_of_contact if point_of_contact && !point_of_contact.empty?
    return parent.effective_contact if parent
    return owning_team.effective_contact if owning_team

    nil
  end

  def current_state
    leaf? ? attributes.current_state : hierarchy.derived_state(STATE_PRIORITY)
  end

  def with_state(state:)
    self.class.new(attributes: attributes.with_state(state), loaders: loaders)
  end

  def active?
    ACTIVE_STATES.include?(current_state)
  end

  def health = project_health.health
  def health_trend = project_health.health_trend
  def latest_health_update = project_health.latest_health_update
  def health_updates_for_tooltip = project_health.health_updates_for_tooltip
  def children_health_for_tooltip = project_health.children_health_for_tooltip

  private

  attr_reader :attributes, :loaders

  def hierarchy
    @hierarchy ||= ProjectHierarchy.new(
      children_loader: loaders.children && -> { loaders.children.call(self) },
      parent_loader: loaders.parent && -> { loaders.parent.call(self) },
      owner: self
    )
  end

  def project_health
    @project_health ||= ProjectHealth.new(
      health_updates_loader: loaders.health_updates && -> { loaders.health_updates.call(self) },
      weekly_health_updates_loader: loaders.weekly_health_updates && -> { loaders.weekly_health_updates.call(self) },
      children_loader: -> { children },
      current_date: loaders.current_date || Date.today
    )
  end

  def state_valid?
    ALLOWED_STATES.include?(current_state)
  end
end
