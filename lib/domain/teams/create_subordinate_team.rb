require_relative '../support/result'
require_relative 'team'

class CreateSubordinateTeam
  def initialize(team_repository:)
    @team_repository = team_repository
  end

  def perform(parent_id:, name:, mission: '', vision: '', point_of_contact: '')
    @parent_id = parent_id
    @attributes = { name:, mission:, vision:, point_of_contact: }

    return parent_not_found_failure unless parent_team
    return parent_has_projects_failure if parent_has_projects?
    return invalid_team_failure unless team.valid?
    return duplicate_name_failure unless unique_name?

    save_team
    link_team
    success
  end

  private

  attr_reader :team_repository, :parent_id, :attributes

  def parent_team
    @parent_team ||= team_repository.find(parent_id)
  end

  def team
    @team ||= Team.new(**attributes)
  end

  def unique_name?
    !team_repository.exists_with_name?(team.name)
  end

  def parent_has_projects?
    team_repository.has_owned_projects?(team_id: parent_id)
  end

  def save_team
    team_repository.save(team)
  end

  def link_team
    order = team_repository.next_subordinate_team_order(parent_id: parent_id)
    team_repository.link_subordinate_team(parent_id: parent_id, child: team, order: order)
  end

  def success
    Result.success(value: team)
  end

  def parent_not_found_failure
    failure('team not found')
  end

  def invalid_team_failure
    failure(team.errors)
  end

  def duplicate_name_failure
    failure('team name must be unique')
  end

  def parent_has_projects_failure
    failure('teams with owned projects cannot have subordinate teams')
  end

  def failure(errors)
    Result.failure(errors: errors)
  end
end
