require_relative '../support/result'
require_relative 'team'

class UpdateTeam
  def initialize(team_repository:)
    @team_repository = team_repository
  end

  def perform(id:, name:, mission: '', vision: '', point_of_contact: '', archived: false)
    existing_team = team_repository.find(id)
    return Result.failure(errors: ['team not found']) unless existing_team

    updated_team = Team.new(
      name: name,
      mission: mission,
      vision: vision,
      point_of_contact: point_of_contact,
      archived: archived
    )

    return Result.failure(errors: updated_team.errors) unless updated_team.valid?

    team_repository.save(id: id, team: updated_team)
    Result.success(value: updated_team)
  end

  private

  attr_reader :team_repository
end
