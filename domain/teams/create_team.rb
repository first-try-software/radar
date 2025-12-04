require_relative '../support/result'
require_relative 'team'

class CreateTeam
  def initialize(team_repository:)
    @team_repository = team_repository
  end

  def perform(name:, mission: '', vision: '', point_of_contact: '')
    team = Team.new(
      name: name,
      mission: mission,
      vision: vision,
      point_of_contact: point_of_contact
    )

    return failure(team) unless team.valid?

    team_repository.save(team)
    Result.success(value: team)
  end

  private

  attr_reader :team_repository

  def failure(team)
    Result.failure(errors: team.errors)
  end
end
