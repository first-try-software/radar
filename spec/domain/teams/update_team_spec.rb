require 'spec_helper'
require_relative '../../../domain/teams/update_team'
require_relative '../../../domain/teams/team'

RSpec.describe UpdateTeam do
  class UpdateTeamRepository
    attr_reader :records

    def initialize
      @records = {}
    end

    def seed(id:, team:)
      records[id] = team
    end

    def find(id)
      records[id]
    end

    def save(id:, team:)
      records[id] = team
    end
  end

  it 'looks up the existing team by id' do
    repository = UpdateTeamRepository.new
    action = described_class.new(team_repository: repository)

    expect(repository).to receive(:find).with('team-123').and_return(Team.new(name: 'Platform'))

    action.perform(id: 'team-123', name: 'Platform 2')
  end

  it 'stores the new team over the existing record' do
    repository = UpdateTeamRepository.new
    repository.seed(id: 'team-123', team: Team.new(name: 'Platform'))
    action = described_class.new(team_repository: repository)

    action.perform(id: 'team-123', name: 'Platform 2', mission: 'New mission', point_of_contact: 'Casey')

    stored_team = repository.records['team-123']
    expect(stored_team.name).to eq('Platform 2')
  end

  it 'returns a successful result when the update succeeds' do
    repository = UpdateTeamRepository.new
    repository.seed(id: 'team-123', team: Team.new(name: 'Platform'))
    action = described_class.new(team_repository: repository)

    result = action.perform(id: 'team-123', name: 'Platform 2')

    expect(result.success?).to be(true)
  end

  it 'returns the updated team as the result value' do
    repository = UpdateTeamRepository.new
    repository.seed(id: 'team-123', team: Team.new(name: 'Platform'))
    action = described_class.new(team_repository: repository)

    result = action.perform(id: 'team-123', name: 'Platform 2')

    expect(result.value).to be_a(Team)
  end

  it 'returns no errors when the update succeeds' do
    repository = UpdateTeamRepository.new
    repository.seed(id: 'team-123', team: Team.new(name: 'Platform'))
    action = described_class.new(team_repository: repository)

    result = action.perform(id: 'team-123', name: 'Platform 2')

    expect(result.errors).to eq([])
  end

  it 'returns a failure result when the team cannot be found' do
    repository = UpdateTeamRepository.new
    action = described_class.new(team_repository: repository)

    result = action.perform(id: 'missing', name: 'Platform 2')

    expect(result.success?).to be(false)
  end

  it 'returns errors when the team cannot be found' do
    repository = UpdateTeamRepository.new
    action = described_class.new(team_repository: repository)

    result = action.perform(id: 'missing', name: 'Platform 2')

    expect(result.errors).to eq(['team not found'])
  end

  it 'returns a failure result when the new team is invalid' do
    repository = UpdateTeamRepository.new
    repository.seed(id: 'team-123', team: Team.new(name: 'Platform'))
    action = described_class.new(team_repository: repository)

    result = action.perform(id: 'team-123', name: '')

    expect(result.success?).to be(false)
  end

  it 'does not store a new team when it is invalid' do
    repository = UpdateTeamRepository.new
    repository.seed(id: 'team-123', team: Team.new(name: 'Platform'))
    action = described_class.new(team_repository: repository)

    action.perform(id: 'team-123', name: '')

    expect(repository.records['team-123'].name).to eq('Platform')
  end

  it 'returns validation errors when the new team is invalid' do
    repository = UpdateTeamRepository.new
    repository.seed(id: 'team-123', team: Team.new(name: 'Platform'))
    action = described_class.new(team_repository: repository)

    result = action.perform(id: 'team-123', name: '')

    expect(result.errors).to eq(['name must be present'])
  end
end
