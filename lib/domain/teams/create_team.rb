require_relative '../support/result'
require_relative 'team'

class CreateTeam
  def initialize(team_repository:)
    @team_repository = team_repository
  end

  def perform(name:, mission: '', vision: '', point_of_contact: '')
    @attributes = { name:, mission:, vision:, point_of_contact: }

    return invalid_team_failure unless team.valid?

    save
    success
  end

  private

  attr_reader :team_repository, :attributes

  def team
    @team ||= Team.new(**attributes)
  end

  def invalid_team_failure
    failure(team.errors)
  end

  def save
    team_repository.save(team)
  end

  def success
    Result.success(value: team)
  end

  def failure(errors)
    Result.failure(errors: errors)
  end
end
