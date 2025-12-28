require_relative '../support/result'
require_relative 'team'

class UpdateTeam
  def initialize(team_repository:)
    @team_repository = team_repository
  end

  def perform(id:, name: nil, description: nil, point_of_contact: nil, archived: nil)
    @id = id
    @provided_attrs = { name:, description:, point_of_contact:, archived: }

    return team_not_found_failure unless existing_team
    return invalid_team_failure unless updated_team.valid?

    save
    success
  end

  private

  attr_reader :team_repository, :id, :provided_attrs

  def existing_team
    @existing_team ||= team_repository.find(id)
  end

  def merged_attributes
    {
      name: provided_attrs[:name] || existing_team.name,
      description: provided_attrs[:description].nil? ? existing_team.description : provided_attrs[:description],
      point_of_contact: provided_attrs[:point_of_contact].nil? ? existing_team.point_of_contact : provided_attrs[:point_of_contact],
      archived: provided_attrs[:archived].nil? ? existing_team.archived? : provided_attrs[:archived]
    }
  end

  def updated_team
    @updated_team ||= Team.new(**merged_attributes)
  end

  def team_not_found_failure
    failure('team not found')
  end

  def invalid_team_failure
    failure(updated_team.errors)
  end

  def save
    team_repository.update(id: id, team: updated_team)
  end

  def success
    Result.success(value: updated_team)
  end

  def failure(errors)
    Result.failure(errors: errors)
  end
end
