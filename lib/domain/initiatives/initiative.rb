require_relative '../support/health_rollup'

class Initiative
  ALLOWED_STATES = [:new, :todo, :in_progress, :blocked, :on_hold, :done].freeze
  CASCADING_STATES = [:todo, :on_hold, :done].freeze
  STATE_PRIORITY = [:blocked, :in_progress, :on_hold, :todo, :new, :done].freeze

  attr_reader :name, :description, :point_of_contact, :current_state

  def initialize(name:, description: '', point_of_contact: '', archived: false, current_state: :new, related_projects_loader: nil)
    @name = name.to_s
    @description = description.to_s
    @point_of_contact = point_of_contact.to_s
    @archived = archived
    @current_state = current_state.to_s.to_sym
    @related_projects_loader = related_projects_loader
    @related_projects = nil
  end

  def valid?
    name_valid? && state_valid?
  end

  def errors
    errs = []
    errs << 'name must be present' unless name_valid?
    errs << 'state must be valid' unless state_valid?
    errs
  end

  def archived?
    !!@archived
  end

  def related_projects
    @related_projects ||= load_related_projects
  end

  def health
    HealthRollup.rollup(related_projects)
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
    self.class.new(
      name: name,
      description: description,
      point_of_contact: point_of_contact,
      archived: archived?,
      current_state: state,
      related_projects_loader: related_projects_loader
    )
  end

  private

  attr_reader :related_projects_loader

  def name_valid?
    !name.strip.empty?
  end

  def state_valid?
    ALLOWED_STATES.include?(current_state)
  end

  def load_related_projects
    related_projects_loader ? Array(related_projects_loader.call(self)) : []
  end
end
