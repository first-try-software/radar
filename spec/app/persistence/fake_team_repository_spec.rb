require 'spec_helper'

require_relative '../../support/persistence/fake_team_repository'

RSpec.describe FakeTeamRepository do
  it 'finds teams by id' do
    repository = FakeTeamRepository.new
    team = Struct.new(:name).new('Platform')
    repository.update(id: 'team-123', team: team)

    result = repository.find('team-123')

    expect(result).to eq(team)
  end

  it 'updates teams by id' do
    repository = FakeTeamRepository.new
    team = Struct.new(:name).new('Platform')

    repository.update(id: 'team-123', team: team)

    expect(repository.find('team-123')).to eq(team)
  end

  it 'saves new teams without specifying an id' do
    repository = FakeTeamRepository.new
    team = Struct.new(:name).new('Platform')

    repository.save(team)

    expect(repository.exists_with_name?('Platform')).to be(true)
  end

  it 'checks for name uniqueness' do
    repository = FakeTeamRepository.new
    team = Struct.new(:name).new('Platform')
    repository.update(id: 'team-123', team: team)

    expect(repository.exists_with_name?('Platform')).to be(true)
    expect(repository.exists_with_name?('Other')).to be(false)
  end

  it 'tracks owned project relationships with incremental order' do
    repository = FakeTeamRepository.new
    project = Struct.new(:name).new('Project A')

    repository.link_owned_project(team_id: 'team-123', project: project, order: 0)

    expect(repository.next_owned_project_order(team_id: 'team-123')).to eq(1)
  end

  it 'tracks subordinate team relationships with incremental order' do
    repository = FakeTeamRepository.new
    child = Struct.new(:name).new('Child')

    repository.link_subordinate_team(parent_id: 'team-123', child: child, order: 0)

    expect(repository.next_subordinate_team_order(parent_id: 'team-123')).to eq(1)
  end
end
