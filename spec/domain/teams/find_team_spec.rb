require 'spec_helper'
require_relative '../../../domain/teams/find_team'
require_relative '../../../domain/teams/team'

RSpec.describe FindTeam do
  class FindTeamRepository
    def initialize
      @records = {}
    end

    def seed(id:, team:)
      records[id] = team
    end

    def find(id)
      records[id]
    end

    private

    attr_reader :records
  end

  it 'looks up the team by id' do
    repository = FindTeamRepository.new
    action = described_class.new(team_repository: repository)

    expect(repository).to receive(:find).with('team-123').and_return(Team.new(name: 'Platform'))

    action.perform(id: 'team-123')
  end

  it 'returns a successful result when the team exists' do
    repository = FindTeamRepository.new
    repository.seed(id: 'team-123', team: Team.new(name: 'Platform'))
    action = described_class.new(team_repository: repository)

    result = action.perform(id: 'team-123')

    expect(result.success?).to be(true)
  end

  it 'returns the found team as the result value' do
    repository = FindTeamRepository.new
    repository.seed(id: 'team-123', team: Team.new(name: 'Platform'))
    action = described_class.new(team_repository: repository)

    result = action.perform(id: 'team-123')

    expect(result.value).to be_a(Team)
  end

  it 'returns no errors when the team exists' do
    repository = FindTeamRepository.new
    repository.seed(id: 'team-123', team: Team.new(name: 'Platform'))
    action = described_class.new(team_repository: repository)

    result = action.perform(id: 'team-123')

    expect(result.errors).to eq([])
  end

  it 'returns a failure result when the team does not exist' do
    repository = FindTeamRepository.new
    action = described_class.new(team_repository: repository)

    result = action.perform(id: 'missing')

    expect(result.success?).to be(false)
  end

  it 'returns errors when the team does not exist' do
    repository = FindTeamRepository.new
    action = described_class.new(team_repository: repository)

    result = action.perform(id: 'missing')

    expect(result.errors).to eq(['team not found'])
  end
end
