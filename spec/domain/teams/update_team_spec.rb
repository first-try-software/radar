require 'spec_helper'
require_relative '../../../domain/teams/update_team'
require_relative '../../../domain/teams/team'
require_relative '../../support/persistence/fake_team_repository'

RSpec.describe UpdateTeam do
  it 'looks up the existing team by id' do
    repository = FakeTeamRepository.new
    action = described_class.new(team_repository: repository)

    expect(repository).to receive(:find).with('team-123').and_return(Team.new(name: 'Platform'))

    action.perform(id: 'team-123', name: 'Platform 2')
  end

  it 'stores the new team over the existing record' do
    repository = FakeTeamRepository.new
    repository.update(id: 'team-123', team: Team.new(name: 'Platform'))
    action = described_class.new(team_repository: repository)

    action.perform(id: 'team-123', name: 'Platform 2', mission: 'New mission', point_of_contact: 'Casey')

    stored_team = repository.find('team-123')
    expect(stored_team.name).to eq('Platform 2')
  end

  it 'returns a successful result when the update succeeds' do
    repository = FakeTeamRepository.new
    repository.update(id: 'team-123', team: Team.new(name: 'Platform'))
    action = described_class.new(team_repository: repository)

    result = action.perform(id: 'team-123', name: 'Platform 2')

    expect(result.success?).to be(true)
  end

  it 'returns the updated team as the result value' do
    repository = FakeTeamRepository.new
    repository.update(id: 'team-123', team: Team.new(name: 'Platform'))
    action = described_class.new(team_repository: repository)

    result = action.perform(id: 'team-123', name: 'Platform 2')

    expect(result.value).to be_a(Team)
  end

  it 'returns no errors when the update succeeds' do
    repository = FakeTeamRepository.new
    repository.update(id: 'team-123', team: Team.new(name: 'Platform'))
    action = described_class.new(team_repository: repository)

    result = action.perform(id: 'team-123', name: 'Platform 2')

    expect(result.errors).to eq([])
  end

  it 'returns a failure result when the team cannot be found' do
    repository = FakeTeamRepository.new
    action = described_class.new(team_repository: repository)

    result = action.perform(id: 'missing', name: 'Platform 2')

    expect(result.success?).to be(false)
  end

  it 'returns errors when the team cannot be found' do
    repository = FakeTeamRepository.new
    action = described_class.new(team_repository: repository)

    result = action.perform(id: 'missing', name: 'Platform 2')

    expect(result.errors).to eq(['team not found'])
  end

  it 'returns a failure result when the new team is invalid' do
    repository = FakeTeamRepository.new
    repository.update(id: 'team-123', team: Team.new(name: 'Platform'))
    action = described_class.new(team_repository: repository)

    result = action.perform(id: 'team-123', name: '')

    expect(result.success?).to be(false)
  end

  it 'does not store a new team when it is invalid' do
    repository = FakeTeamRepository.new
    repository.update(id: 'team-123', team: Team.new(name: 'Platform'))
    action = described_class.new(team_repository: repository)

    action.perform(id: 'team-123', name: '')

    expect(repository.find('team-123').name).to eq('Platform')
  end

  it 'returns validation errors when the new team is invalid' do
    repository = FakeTeamRepository.new
    repository.update(id: 'team-123', team: Team.new(name: 'Platform'))
    action = described_class.new(team_repository: repository)

    result = action.perform(id: 'team-123', name: '')

    expect(result.errors).to eq(['name must be present'])
  end
end
