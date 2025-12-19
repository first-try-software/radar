require 'spec_helper'
require 'domain/teams/create_team'
require 'domain/teams/team'
require_relative '../../support/persistence/fake_team_repository'

RSpec.describe CreateTeam do
  it 'stores the created team in the provided repository' do
    repository = FakeTeamRepository.new
    action = described_class.new(team_repository: repository)

    action.perform(name: 'Platform', description: 'Enable delivery velocity', point_of_contact: 'Jordan')

    stored_team = repository.find('Platform')
    expect(stored_team.name).to eq('Platform')
  end

  it 'returns a successful result' do
    repository = FakeTeamRepository.new
    action = described_class.new(team_repository: repository)

    result = action.perform(name: 'Platform')

    expect(result.success?).to be(true)
  end

  it 'returns the stored team as the result value' do
    repository = FakeTeamRepository.new
    action = described_class.new(team_repository: repository)

    result = action.perform(name: 'Platform')

    expect(result.value).to be_a(Team)
  end

  it 'returns no errors on success' do
    repository = FakeTeamRepository.new
    action = described_class.new(team_repository: repository)

    result = action.perform(name: 'Platform')

    expect(result.errors).to eq([])
  end

  it 'returns a failure result when the team is invalid' do
    repository = FakeTeamRepository.new
    action = described_class.new(team_repository: repository)

    result = action.perform(name: '')

    expect(result.success?).to be(false)
  end

  it 'does not store a team when it is invalid' do
    repository = FakeTeamRepository.new
    action = described_class.new(team_repository: repository)

    action.perform(name: '')

    expect(repository.exists_with_name?('')).to be(false)
  end

  it 'returns validation errors when the team is invalid' do
    repository = FakeTeamRepository.new
    action = described_class.new(team_repository: repository)

    result = action.perform(name: '')

    expect(result.errors).to eq(['name must be present'])
  end
end
