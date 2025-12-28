require 'spec_helper'
require 'domain/teams/update_team'
require 'domain/teams/team'
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

    action.perform(id: 'team-123', name: 'Platform 2', description: 'New description', point_of_contact: 'Casey')

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

  it 'preserves existing name when name is not provided' do
    repository = FakeTeamRepository.new
    repository.update(id: 'team-123', team: Team.new(name: 'Platform', description: 'Old desc'))
    action = described_class.new(team_repository: repository)

    action.perform(id: 'team-123', description: 'New desc')

    expect(repository.find('team-123').name).to eq('Platform')
    expect(repository.find('team-123').description).to eq('New desc')
  end

  it 'preserves existing description when description is not provided' do
    repository = FakeTeamRepository.new
    repository.update(id: 'team-123', team: Team.new(name: 'Platform', description: 'Old desc'))
    action = described_class.new(team_repository: repository)

    action.perform(id: 'team-123', name: 'New Name')

    expect(repository.find('team-123').description).to eq('Old desc')
  end

  it 'preserves existing point_of_contact when not provided' do
    repository = FakeTeamRepository.new
    repository.update(id: 'team-123', team: Team.new(name: 'Platform', point_of_contact: 'Casey'))
    action = described_class.new(team_repository: repository)

    action.perform(id: 'team-123', name: 'New Name')

    expect(repository.find('team-123').point_of_contact).to eq('Casey')
  end

  it 'preserves existing archived status when not provided' do
    repository = FakeTeamRepository.new
    repository.update(id: 'team-123', team: Team.new(name: 'Platform', archived: true))
    action = described_class.new(team_repository: repository)

    action.perform(id: 'team-123', name: 'New Name')

    expect(repository.find('team-123').archived?).to be(true)
  end

  it 'allows setting description to empty string' do
    repository = FakeTeamRepository.new
    repository.update(id: 'team-123', team: Team.new(name: 'Platform', description: 'Old desc'))
    action = described_class.new(team_repository: repository)

    action.perform(id: 'team-123', description: '')

    expect(repository.find('team-123').description).to eq('')
  end
end
