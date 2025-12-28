require_relative '../support/result'
require_relative 'team'
require_relative 'team_attributes'

class CreateTeam
  def initialize(team_repository:)
    @team_repository = team_repository
  end

  def perform(name:, description: '', point_of_contact: '')
    @attrs = TeamAttributes.new(name:, description:, point_of_contact:)

    return invalid_team_failure unless team.valid?

    save
    success
  end

  private

  attr_reader :team_repository, :attrs

  def team
    @team ||= Team.new(attributes: attrs)
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
