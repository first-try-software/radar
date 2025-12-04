require_relative '../support/result'
require_relative 'team'

class UpdateTeam
  def initialize(team_repository:)
    @team_repository = team_repository
  end

  def perform(id:, name:, mission: '', vision: '', point_of_contact: '', archived: false)
    @id = id
    @attributes = { name:, mission:, vision:, point_of_contact:, archived: }

    return team_not_found_failure unless existing_team
    return invalid_team_failure unless updated_team.valid?

    save
    success
  end

  private

  attr_reader :team_repository, :id, :attributes

  def existing_team
    @existing_team ||= team_repository.find(id)
  end

  def updated_team
    @updated_team ||= Team.new(**attributes)
  end

  def team_not_found_failure
    failure(['team not found'])
  end

  def invalid_team_failure
    failure(updated_team.errors)
  end

  def save
    team_repository.save(id: id, team: updated_team)
  end

  def success
    Result.success(value: updated_team)
  end

  def failure(errors)
    Result.failure(errors: errors)
  end
end
