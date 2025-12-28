require_relative '../support/result'
require_relative 'team'
require_relative 'team_attributes'

class CreateSubordinateTeam
  def initialize(team_repository:)
    @team_repository = team_repository
  end

  def perform(parent_id:, name:, description: '', point_of_contact: '')
    @parent_id = parent_id
    @attrs = TeamAttributes.new(name:, description:, point_of_contact:)

    return parent_not_found_failure unless parent_team
    return invalid_team_failure unless team.valid?
    return duplicate_name_failure unless unique_name?

    save_team
    link_team
    success
  end

  private

  attr_reader :team_repository, :parent_id, :attrs

  def parent_team
    @parent_team ||= team_repository.find(parent_id)
  end

  def team
    @team ||= Team.new(attributes: attrs)
  end

  def unique_name?
    !team_repository.exists_with_name?(team.name)
  end

  def save_team
    @saved_team = team_repository.save(team)
  end

  def link_team
    order = team_repository.next_subordinate_team_order(parent_id: parent_id)
    team_repository.link_subordinate_team(parent_id: parent_id, child: team, order: order)
  end

  def success
    Result.success(value: @saved_team)
  end

  def parent_not_found_failure
    failure('team not found')
  end

  def invalid_team_failure
    failure(team.errors)
  end

  def duplicate_name_failure
    failure('team name must be unique')
  end

  def failure(errors)
    Result.failure(errors: errors)
  end
end
