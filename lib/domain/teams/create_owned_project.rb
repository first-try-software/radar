require_relative '../support/result'
require_relative '../projects/project'
require_relative '../projects/project_attributes'

class CreateOwnedProject
  def initialize(team_repository:, project_repository:)
    @team_repository = team_repository
    @project_repository = project_repository
  end

  def perform(team_id:, name:, description: '', point_of_contact: '')
    @team_id = team_id
    @attrs = ProjectAttributes.new(name:, description:, point_of_contact:)

    return team_not_found_failure unless team
    return team_has_subordinates_failure if team_has_subordinates?
    return invalid_project_failure unless project.valid?
    return duplicate_name_failure unless unique_name?

    save_project
    link_project
    success
  end

  private

  attr_reader :team_repository, :project_repository, :team_id, :attrs

  def team
    @team ||= team_repository.find(team_id)
  end

  def project
    @project ||= Project.new(attributes: attrs)
  end

  def unique_name?
    !project_repository.exists_with_name?(project.name)
  end

  def team_has_subordinates?
    team_repository.has_subordinate_teams?(team_id: team_id)
  end

  def save_project
    project_repository.save(project)
  end

  def link_project
    order = team_repository.next_owned_project_order(team_id: team_id)
    team_repository.link_owned_project(team_id: team_id, project: project, order: order)
  end

  def success
    Result.success(value: project)
  end

  def team_not_found_failure
    failure('team not found')
  end

  def invalid_project_failure
    failure(project.errors)
  end

  def duplicate_name_failure
    failure('project name must be unique')
  end

  def team_has_subordinates_failure
    failure('teams with subordinate teams cannot own projects')
  end

  def failure(errors)
    Result.failure(errors: errors)
  end
end
