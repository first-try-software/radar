require_relative '../support/result'

class FindTeam
  def initialize(team_repository:)
    @team_repository = team_repository
  end

  def perform(id:)
    team = team_repository.find(id)

    return team_not_found_failure unless team

    Result.success(value: team)
  end

  private

  attr_reader :team_repository

  def team_not_found_failure
    Result.failure(errors: 'team not found')
  end
end
