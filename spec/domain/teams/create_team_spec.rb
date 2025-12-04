require 'spec_helper'
require_relative '../../../domain/teams/create_team'
require_relative '../../../domain/teams/team'

RSpec.describe CreateTeam do
  class CreateTeamRepository
    attr_reader :records

    def initialize
      @records = []
    end

    def save(team)
      records << team
    end
  end

  it 'stores the created team in the provided repository' do
    repository = CreateTeamRepository.new
    action = described_class.new(team_repository: repository)

    action.perform(name: 'Platform', mission: 'Enable delivery velocity', point_of_contact: 'Jordan')

    stored_team = repository.records.first
    expect(stored_team.name).to eq('Platform')
  end

  it 'returns a successful result' do
    repository = CreateTeamRepository.new
    action = described_class.new(team_repository: repository)

    result = action.perform(name: 'Platform')

    expect(result.success?).to be(true)
  end

  it 'returns the stored team as the result value' do
    repository = CreateTeamRepository.new
    action = described_class.new(team_repository: repository)

    result = action.perform(name: 'Platform')

    expect(result.value).to be_a(Team)
  end

  it 'returns no errors on success' do
    repository = CreateTeamRepository.new
    action = described_class.new(team_repository: repository)

    result = action.perform(name: 'Platform')

    expect(result.errors).to eq([])
  end

  it 'returns a failure result when the team is invalid' do
    repository = CreateTeamRepository.new
    action = described_class.new(team_repository: repository)

    result = action.perform(name: '')

    expect(result.success?).to be(false)
  end

  it 'does not store a team when it is invalid' do
    repository = CreateTeamRepository.new
    action = described_class.new(team_repository: repository)

    action.perform(name: '')

    expect(repository.records).to be_empty
  end

  it 'returns validation errors when the team is invalid' do
    repository = CreateTeamRepository.new
    action = described_class.new(team_repository: repository)

    result = action.perform(name: '')

    expect(result.errors).to eq(['name must be present'])
  end
end
