require_relative '../support/result'
require_relative 'team'

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
      name: team.name,
      mission: team.mission,
      vision: team.vision,
      point_of_contact: team.point_of_contact,
      archived: true
    )
  end

  def team_not_found_failure
    failure('team not found')
  end

  def save
    team_repository.save(id: id, team: archived_team)
  end

  def success
    Result.success(value: archived_team)
  end

  def failure(errors)
    Result.failure(errors: errors)
  end
end
