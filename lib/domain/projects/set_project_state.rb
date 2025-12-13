require_relative '../support/result'
require_relative 'project'

class SetProjectState
  SETTABLE_STATES = [:todo, :in_progress, :blocked, :on_hold, :done].freeze

  def initialize(project_repository:)
    @project_repository = project_repository
  end

  def perform(id:, state:)
    @id = id
    @state = state&.to_sym

    return project_not_found_failure unless project
    return invalid_state_failure unless valid_state?

    update_leaf_descendants
    Result.success(value: refreshed_project)
  end

  private

  attr_reader :project_repository, :id

  def project
    @project ||= project_repository.find(id)
  end

  def refreshed_project
    project_repository.find(id)
  end

  def valid_state?
    SETTABLE_STATES.include?(@state)
  end

  def update_leaf_descendants
    leaves = project.leaf_descendants
    leaves.each do |leaf|
      updated_leaf = leaf.with_state(state: @state)
      project_repository.update_by_name(name: leaf.name, project: updated_leaf)
    end
  end

  def project_not_found_failure
    failure('project not found')
  end

  def invalid_state_failure
    failure('invalid state')
  end

  def failure(errors)
    Result.failure(errors: errors)
  end
end
