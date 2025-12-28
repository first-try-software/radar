require_relative '../support/result'
require_relative 'team'
require_relative 'team_attributes'

class ArchiveTeam
  def initialize(team_repository:)
    @team_repository = team_repository
  end

  def perform(id:)
    @id = id

    return team_not_found_failure unless team

    save
    success
  end

  private

  attr_reader :team_repository, :id

  def team
    @team ||= team_repository.find(id)
  end

  def archived_team
    @archived_team ||= Team.new(
      attributes: TeamAttributes.new(
        id: team.id,
        name: team.name,
        description: team.description,
        point_of_contact: team.point_of_contact,
        archived: true
      )
    )
  end

  def team_not_found_failure
    failure('team not found')
  end

  def save
    team_repository.update(id: id, team: archived_team)
  end

  def success
    Result.success(value: archived_team)
  end

  def failure(errors)
    Result.failure(errors: errors)
  end
end
