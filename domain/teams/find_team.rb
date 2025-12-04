require_relative '../support/result'

class FindTeam
  def initialize(team_repository:)
    @team_repository = team_repository
  end

  def perform(id:)
    team = team_repository.find(id)
    return Result.failure(errors: ['team not found']) unless team

    Result.success(value: team)
  end

  private

  attr_reader :team_repository
end
