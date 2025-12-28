require 'spec_helper'
require 'domain/teams/archive_team'
require_relative '../../support/domain/team_builder'
require_relative '../../support/persistence/fake_team_repository'

RSpec.describe ArchiveTeam do
  include TeamBuilder

  it 'looks up the team by id' do
    repository = FakeTeamRepository.new
    action = described_class.new(team_repository: repository)

    expect(repository).to receive(:find).with('team-123').and_return(build_team(name: 'Platform'))

    action.perform(id: 'team-123')
  end

  it 'archives the team and saves it' do
    repository = FakeTeamRepository.new
    repository.update(id: 'team-123', team: build_team(name: 'Platform'))
    action = described_class.new(team_repository: repository)

    action.perform(id: 'team-123')

    stored_team = repository.find('team-123')
    expect(stored_team).to be_archived
  end

  it 'returns a successful result when the team is archived' do
    repository = FakeTeamRepository.new
    repository.update(id: 'team-123', team: build_team(name: 'Platform'))
    action = described_class.new(team_repository: repository)

    result = action.perform(id: 'team-123')

    expect(result.success?).to be(true)
  end

  it 'returns the archived team as the result value' do
    repository = FakeTeamRepository.new
    repository.update(id: 'team-123', team: build_team(name: 'Platform'))
    action = described_class.new(team_repository: repository)

    result = action.perform(id: 'team-123')

    expect(result.value).to be_archived
  end

  it 'returns no errors when the team is archived' do
    repository = FakeTeamRepository.new
    repository.update(id: 'team-123', team: build_team(name: 'Platform'))
    action = described_class.new(team_repository: repository)

    result = action.perform(id: 'team-123')

    expect(result.errors).to eq([])
  end

  it 'returns a failure result when the team cannot be found' do
    repository = FakeTeamRepository.new
    action = described_class.new(team_repository: repository)

    result = action.perform(id: 'missing')

    expect(result.success?).to be(false)
  end

  it 'returns errors when the team cannot be found' do
    repository = FakeTeamRepository.new
    action = described_class.new(team_repository: repository)

    result = action.perform(id: 'missing')

    expect(result.errors).to eq(['team not found'])
  end
end
