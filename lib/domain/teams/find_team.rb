require_relative '../support/result'

class FindTeam
  def initialize(team_repository:)
    @team_repository = team_repository
  end

  def perform(id:)
    @id = id

    return team_not_found_failure unless team

    success
  end

  private

  attr_reader :team_repository, :id

  def team
    @team ||= team_repository.find(id)
  end

  def success
    Result.success(value: team)
  end

  def team_not_found_failure
    Result.failure(errors: 'team not found')
  end
end
