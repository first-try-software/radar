require_relative '../support/result'

class LinkOwnedProject
  def initialize(team_repository:, project_repository:)
    @team_repository = team_repository
    @project_repository = project_repository
  end

  def perform(team_id:, project_id:)
    @team_id = team_id
    @project_id = project_id

    return team_not_found_failure unless team
    return team_has_subordinates_failure if team_has_subordinates?
    return project_not_found_failure unless project

    link_project
    success
  end

  private

  attr_reader :team_repository, :project_repository, :team_id, :project_id

  def team
    @team ||= team_repository.find(team_id)
  end

  def project
    @project ||= project_repository.find(project_id)
  end

  def link_project
    order = team_repository.next_owned_project_order(team_id: team_id)
    team_repository.link_owned_project(team_id: team_id, project: project, order: order)
  end

  def success
    Result.success(value: project)
  end

  def team_not_found_failure
    Result.failure(errors: 'team not found')
  end

  def project_not_found_failure
    Result.failure(errors: 'project not found')
  end

  def team_has_subordinates?
    team_repository.has_subordinate_teams?(team_id: team_id)
  end

  def team_has_subordinates_failure
    Result.failure(errors: 'teams with subordinate teams cannot own projects')
  end
end
