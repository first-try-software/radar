class FakeTeamRepository
  def initialize(teams: {})
    @records = teams
    @owned_relationships = []
    @subordinate_relationships = []
  end

  def find(id)
    records[id]
  end

  def update(id:, team:)
    records[id] = team
  end

  def save(team)
    records[team.name] = team
  end

  def exists_with_name?(name)
    records.values.any? { |team| team.name == name }
  end

  def link_owned_project(team_id:, project:, order:)
    owned_relationships << { team_id:, project:, order: }
  end

  def owned_relationships_for(team_id:)
    owned_relationships.select { |rel| rel[:team_id] == team_id }
  end

  def next_owned_project_order(team_id:)
    max = owned_relationships_for(team_id: team_id).map { |rel| rel[:order] }.max
    max ? max + 1 : 0
  end

  def link_subordinate_team(parent_id:, child:, order:)
    subordinate_relationships << { parent_id:, child:, order: }
  end

  def subordinate_relationships_for(parent_id:)
    subordinate_relationships.select { |rel| rel[:parent_id] == parent_id }
  end

  def next_subordinate_team_order(parent_id:)
    max = subordinate_relationships_for(parent_id: parent_id).map { |rel| rel[:order] }.max
    max ? max + 1 : 0
  end

  def has_subordinate_teams?(team_id:)
    subordinate_relationships_for(parent_id: team_id).any?
  end

  def has_owned_projects?(team_id:)
    owned_relationships_for(team_id: team_id).any?
  end

  private

  attr_reader :records, :owned_relationships, :subordinate_relationships
end
