require 'spec_helper'
require_relative '../../../domain/teams/create_subordinate_team'
require_relative '../../../domain/teams/team'

RSpec.describe CreateSubordinateTeam do
  class CreateSubordinateTeamRepository
    attr_reader :teams, :saved_teams, :relationships

    def initialize(teams: {})
      @teams = teams
      @saved_teams = []
      @relationships = []
    end

    def find(id)
      teams[id]
    end

    def save(team)
      saved_teams << team
    end

    def link_subordinate_team(parent_id:, child:, order:)
      relationships << { parent_id:, child:, order: }
    end

    def next_subordinate_team_order(parent_id:)
      max = relationships.select { |rel| rel[:parent_id] == parent_id }.map { |rel| rel[:order] }.max
      max ? max + 1 : 0
    end

    def exists_with_name?(name)
      teams.values.any? { |team| team.name == name } ||
        saved_teams.any? { |team| team.name == name }
    end
  end

  it 'fails when the parent team cannot be found' do
    repository = CreateSubordinateTeamRepository.new
    action = described_class.new(team_repository: repository)

    result = action.perform(parent_id: 'team-123', name: 'Child Team')

    expect(result.success?).to be(false)
    expect(result.errors).to eq(['team not found'])
  end

  it 'fails when the subordinate team is invalid' do
    parent = Team.new(name: 'Platform')
    repository = CreateSubordinateTeamRepository.new(teams: { 'team-123' => parent })
    action = described_class.new(team_repository: repository)

    result = action.perform(parent_id: 'team-123', name: '')

    expect(result.success?).to be(false)
    expect(result.errors).to eq(['name must be present'])
  end

  it 'fails when the subordinate team name already exists' do
    parent = Team.new(name: 'Platform')
    repository = CreateSubordinateTeamRepository.new(
      teams: { 'team-123' => parent, 'team-456' => Team.new(name: 'Child Team') }
    )
    action = described_class.new(team_repository: repository)

    result = action.perform(parent_id: 'team-123', name: 'Child Team')

    expect(result.success?).to be(false)
    expect(result.errors).to eq(['team name must be unique'])
  end

  it 'saves the team and links it to the parent team' do
    parent = Team.new(name: 'Platform')
    repository = CreateSubordinateTeamRepository.new(teams: { 'team-123' => parent })
    action = described_class.new(team_repository: repository)

    result = action.perform(
      parent_id: 'team-123',
      name: 'Child Team',
      mission: 'Support',
      vision: 'Clear',
      point_of_contact: 'Alex'
    )

    expect(result.success?).to be(true)
    child = repository.saved_teams.first
    expect(child.name).to eq('Child Team')
    relationship = repository.relationships.first
    expect(relationship[:parent_id]).to eq('team-123')
    expect(relationship[:order]).to eq(0)
  end

  it 'assigns the next order when the parent already has subordinates' do
    parent = Team.new(name: 'Platform')
    repository = CreateSubordinateTeamRepository.new(teams: { 'team-123' => parent })
    repository.link_subordinate_team(parent_id: 'team-123', child: Team.new(name: 'Existing'), order: 0)
    action = described_class.new(team_repository: repository)

    action.perform(parent_id: 'team-123', name: 'Second Child', mission: 'Support')

    expect(repository.relationships.last[:order]).to eq(1)
  end

  it 'fails when a newly saved subordinate team has the same name' do
    parent = Team.new(name: 'Platform')
    repository = CreateSubordinateTeamRepository.new(teams: { 'team-123' => parent })
    action = described_class.new(team_repository: repository)

    action.perform(parent_id: 'team-123', name: 'Child Team')
    result = action.perform(parent_id: 'team-123', name: 'Child Team')

    expect(result.success?).to be(false)
    expect(result.errors).to eq(['team name must be unique'])
  end
end
