require_relative '../support/result'
require_relative 'team'

class ArchiveTeam
  def initialize(team_repository:)
    @team_repository = team_repository
  end

  def perform(id:)
    team = team_repository.find(id)
    return Result.failure(errors: ['team not found']) unless team

    archived_team = Team.new(
      name: team.name,
      mission: team.mission,
      vision: team.vision,
      point_of_contact: team.point_of_contact,
      archived: true
    )

    team_repository.save(id: id, team: archived_team)
    Result.success(value: archived_team)
  end

  private

  attr_reader :team_repository
end
