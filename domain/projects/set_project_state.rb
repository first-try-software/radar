require_relative '../support/result'
require_relative 'project'

class SetProjectState
  STATE_TRANSITIONS = {
    new: [:todo],
    todo: [:in_progress, :blocked, :on_hold, :done],
    in_progress: [:blocked, :on_hold, :done],
    blocked: [:todo, :done],
    on_hold: [:todo, :done],
    done: []
  }.freeze

  def initialize(project_repository:)
    @project_repository = project_repository
  end

  def perform(id:, state:)
    @id = id
    @state = state&.to_sym

    return project_not_found_failure unless project
    return invalid_state_failure unless valid_state?
    return invalid_transition_failure unless allowed_transition?

    updated_project = project.with_state(state: @state)
    project_repository.save(id: id, project: updated_project)
    Result.success(value: updated_project)
  end

  private

  attr_reader :project_repository, :id

  def project
    @project ||= project_repository.find(id)
  end

  def valid_state?
    Project::ALLOWED_STATES.include?(@state)
  end

  def allowed_transition?
    return false if @state.nil?
    return false if project.current_state == @state

    STATE_TRANSITIONS.fetch(project.current_state).include?(@state)
  end

  def project_not_found_failure
    failure('project not found')
  end

  def invalid_state_failure
    failure('invalid state')
  end

  def invalid_transition_failure
    failure('invalid state transition')
  end

  def failure(errors)
    Result.failure(errors: errors)
  end
end
