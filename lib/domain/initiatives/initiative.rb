require_relative '../support/health_rollup'
require_relative 'initiative_attributes'
require_relative 'initiative_loaders'

class Initiative
  CASCADING_STATES = [:todo, :on_hold, :done].freeze
  STATE_PRIORITY = [:blocked, :in_progress, :on_hold, :todo, :new, :done].freeze

  def initialize(attributes:, loaders: InitiativeLoaders.new)
    @attributes = attributes
    @loaders = loaders
  end

  def id = attributes.id
  def name = attributes.name
  def description = attributes.description
  def point_of_contact = attributes.point_of_contact
  def archived? = attributes.archived?
  def current_state = attributes.current_state

  def valid?
    attributes.valid?
  end

  def errors
    attributes.errors
  end

  def related_projects
    @related_projects ||= load_related_projects
  end

  def health
    HealthRollup.health_from_projects(related_projects)
  end

  def health_raw_score
    HealthRollup.score_from_projects(related_projects)
  end

  def leaf_projects
    @leaf_projects ||= related_projects.flat_map do |project|
      project.leaf? ? [project] : project.leaf_descendants
    end.uniq { |p| p.id || p.name }
  end

  def derived_state
    # Derives state from related projects (for blocked/in_progress indicators)
    return current_state if related_projects.empty?

    project_states = related_projects.map(&:current_state)
    STATE_PRIORITY.find { |state| project_states.include?(state) } || current_state
  end

  def projects_in_state(state)
    related_projects.select { |p| p.current_state == state }
  end

  def cascades_state?(state)
    CASCADING_STATES.include?(state.to_sym)
  end

  def with_state(state)
    self.class.new(attributes: attributes.with_state(state), loaders: loaders)
  end

  private

  attr_reader :attributes, :loaders

  def load_related_projects
    loaders.related_projects ? Array(loaders.related_projects.call(self)) : []
  end
end
