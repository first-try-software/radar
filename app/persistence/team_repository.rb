require_relative '../../lib/domain/teams/team'

class TeamRepository
  def initialize(project_repository:)
    @project_repository = project_repository
  end

  def find(id)
    record = TeamRecord.find_by(id: id)
    return nil unless record

    build_entity(record)
  end

  def save(team)
    TeamRecord.create!(
      name: team.name,
      description: team.description,
      point_of_contact: team.point_of_contact,
      archived: team.archived?
    )
  end

  def update(id:, team:)
    record = TeamRecord.find_by(id: id)
    return unless record

    record.update!(
      name: team.name,
      description: team.description,
      point_of_contact: team.point_of_contact,
      archived: team.archived?
    )
  end

  def exists_with_name?(name)
    TeamRecord.exists?(name: name)
  end

  def link_owned_project(team_id:, project:, order:)
    project_record = ProjectRecord.find_by!(name: project.name)
    team_record = TeamRecord.find_by!(id: team_id)

    TeamsProjectRecord.create!(
      team: team_record,
      project: project_record,
      order: order
    )
  end

  def next_owned_project_order(team_id:)
    max = TeamsProjectRecord.where(team_id: team_id).maximum(:order)
    max ? max + 1 : 0
  end

  def owned_projects_for(team_id:)
    TeamsProjectRecord
      .where(team_id: team_id)
      .order(:order)
      .includes(:project)
      .map do |rel|
        {
          team_id: rel.team_id.to_s,
          project: project_repository.find(rel.project_id),
          order: rel.order
        }
      end
  end

  def link_subordinate_team(parent_id:, child:, order:)
    child_record = TeamRecord.find_by!(name: child.name)
    parent_record = TeamRecord.find_by!(id: parent_id)

    TeamsTeamRecord.create!(
      parent: parent_record,
      child: child_record,
      order: order
    )
  end

  def next_subordinate_team_order(parent_id:)
    max = TeamsTeamRecord.where(parent_id: parent_id).maximum(:order)
    max ? max + 1 : 0
  end

  def subordinate_teams_for(parent_id:)
    TeamsTeamRecord
      .where(parent_id: parent_id)
      .order(:order)
      .includes(:child)
      .map do |rel|
        {
          parent_id: rel.parent_id.to_s,
          team: find(rel.child_id),
          order: rel.order
        }
      end
  end

  def unlink_owned_project(team_id:, project_id:)
    TeamsProjectRecord.where(team_id: team_id, project_id: project_id).destroy_all
  end

  def owned_project_exists?(team_id:, project_id:)
    TeamsProjectRecord.exists?(team_id: team_id, project_id: project_id)
  end

  def unlink_subordinate_team(parent_id:, child_id:)
    TeamsTeamRecord.where(parent_id: parent_id, child_id: child_id).destroy_all
  end

  def subordinate_team_exists?(parent_id:, child_id:)
    TeamsTeamRecord.exists?(parent_id: parent_id, child_id: child_id)
  end

  def has_subordinate_teams?(team_id:)
    TeamsTeamRecord.exists?(parent_id: team_id)
  end

  def has_owned_projects?(team_id:)
    TeamsProjectRecord.exists?(team_id: team_id)
  end

  def all_active_roots
    child_ids = TeamsTeamRecord.pluck(:child_id)
    TeamRecord.where(archived: false).where.not(id: child_ids).map { |record| build_entity(record) }
  end

  def all_archived_roots
    child_ids = TeamsTeamRecord.pluck(:child_id)
    TeamRecord.where(archived: true).where.not(id: child_ids).map { |record| build_entity(record) }
  end

  private

  attr_reader :project_repository

  def build_entity(record)
    attributes = TeamAttributes.new(
      id: record.id.to_s,
      name: record.name,
      description: record.description,
      point_of_contact: record.point_of_contact,
      archived: record.archived
    )
    loaders = TeamLoaders.new(
      owned_projects: owned_projects_loader_for(record),
      subordinate_teams: subordinate_teams_loader_for(record),
      parent_team: parent_team_loader_for(record)
    )
    Team.new(attributes: attributes, loaders: loaders)
  end

  def owned_projects_loader_for(record)
    lambda do |_team|
      TeamsProjectRecord
        .where(team_id: record.id)
        .order(:order)
        .includes(:project)
        .map { |rel| project_repository.find(rel.project_id) }
    end
  end

  def subordinate_teams_loader_for(record)
    lambda do |_team|
      TeamsTeamRecord
        .where(parent_id: record.id)
        .order(:order)
        .includes(:child)
        .map { |rel| find(rel.child_id) }
    end
  end

  def parent_team_loader_for(record)
    lambda do |_team|
      parent_rel = TeamsTeamRecord.find_by(child_id: record.id)
      parent_rel ? find(parent_rel.parent_id) : nil
    end
  end
end
