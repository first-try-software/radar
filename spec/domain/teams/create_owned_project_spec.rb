require 'spec_helper'
require 'domain/teams/create_owned_project'
require 'domain/teams/team'
require 'domain/projects/project'
require_relative '../../support/persistence/fake_team_repository'
require_relative '../../support/persistence/fake_project_repository'
require_relative '../../support/project_builder'

RSpec.describe CreateOwnedProject do
  it 'fails when the team cannot be found' do
    team_repository = FakeTeamRepository.new
    project_repository = FakeProjectRepository.new
    action = described_class.new(team_repository: team_repository, project_repository: project_repository)

    result = action.perform(team_id: 'team-123', name: 'Project')

    expect(result.success?).to be(false)
    expect(result.errors).to eq(['team not found'])
  end

  it 'fails when the project is invalid' do
    team = Team.new(name: 'Platform')
    team_repository = FakeTeamRepository.new(teams: { 'team-123' => team })
    project_repository = FakeProjectRepository.new
    action = described_class.new(team_repository: team_repository, project_repository: project_repository)

    result = action.perform(team_id: 'team-123', name: '')

    expect(result.success?).to be(false)
    expect(result.errors).to eq(['name must be present'])
  end

  it 'fails when the project name already exists' do
    team = Team.new(name: 'Platform')
    team_repository = FakeTeamRepository.new(teams: { 'team-123' => team })
    project_repository = FakeProjectRepository.new
    project_repository.save(ProjectBuilder.build(name: 'Project'))
    action = described_class.new(team_repository: team_repository, project_repository: project_repository)

    result = action.perform(team_id: 'team-123', name: 'Project')

    expect(result.success?).to be(false)
    expect(result.errors).to eq(['project name must be unique'])
  end

  it 'succeeds when the team has subordinate teams' do
    team = Team.new(name: 'Platform')
    child_team = Team.new(name: 'Child')
    team_repository = FakeTeamRepository.new(teams: { 'team-123' => team, 'child' => child_team })
    team_repository.link_subordinate_team(parent_id: 'team-123', child: child_team, order: 0)
    project_repository = FakeProjectRepository.new
    action = described_class.new(team_repository: team_repository, project_repository: project_repository)

    result = action.perform(team_id: 'team-123', name: 'Project')

    expect(result.success?).to be(true)
    expect(result.value.name).to eq('Project')
  end

  it 'saves the project and links it to the team' do
    team = Team.new(name: 'Platform')
    team_repository = FakeTeamRepository.new(teams: { 'team-123' => team })
    project_repository = FakeProjectRepository.new
    action = described_class.new(team_repository: team_repository, project_repository: project_repository)

    result = action.perform(
      team_id: 'team-123',
      name: 'Status',
      description: 'Status dashboard',
      point_of_contact: 'Alex'
    )

    expect(result.success?).to be(true)
    project = project_repository.find('Status')
    expect(project.name).to eq('Status')
    relationship = team_repository.owned_relationships_for(team_id: 'team-123').first
    expect(relationship[:team_id]).to eq('team-123')
    expect(relationship[:order]).to eq(0)
  end
end
