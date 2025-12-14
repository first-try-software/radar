require_relative '../support/result'
require_relative 'initiative'

class SetInitiativeState
  SETTABLE_STATES = [:todo, :in_progress, :blocked, :on_hold, :done].freeze

  def initialize(initiative_repository:, project_repository:)
    @initiative_repository = initiative_repository
    @project_repository = project_repository
  end

  def perform(id:, state:, cascade: false)
    @id = id
    @state = state&.to_sym
    @cascade = cascade

    return initiative_not_found_failure unless initiative
    return invalid_state_failure unless valid_state?

    update_initiative_state
    cascade_to_projects if should_cascade?

    Result.success(value: refreshed_initiative)
  end

  private

  attr_reader :initiative_repository, :project_repository, :id

  def initiative
    @initiative ||= initiative_repository.find(id)
  end

  def refreshed_initiative
    initiative_repository.find(id)
  end

  def valid_state?
    SETTABLE_STATES.include?(@state)
  end

  def should_cascade?
    @cascade && Initiative::CASCADING_STATES.include?(@state)
  end

  def update_initiative_state
    initiative_repository.update_state(id: id, state: @state)
  end

  def cascade_to_projects
    initiative.related_projects.each do |project|
      update_project_state(project)
    end
  end

  def update_project_state(project)
    # Update leaf descendants of each related project
    leaves = project.leaf_descendants
    leaves.each do |leaf|
      updated_leaf = leaf.with_state(state: @state)
      project_repository.update_by_name(name: leaf.name, project: updated_leaf)
    end
  end

  def initiative_not_found_failure
    Result.failure(errors: 'initiative not found')
  end

  def invalid_state_failure
    Result.failure(errors: 'invalid state')
  end
end
