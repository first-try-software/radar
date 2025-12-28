require 'spec_helper'
require 'domain/teams/link_owned_project'
require_relative '../../support/domain/team_builder'
require 'domain/projects/project'
require 'domain/projects/project_attributes'
require_relative '../../support/persistence/fake_team_repository'
require_relative '../../support/persistence/fake_project_repository'

RSpec.describe LinkOwnedProject do
  include TeamBuilder

  it 'returns failure when team is not found' do
    team_repository = FakeTeamRepository.new
    project_repository = FakeProjectRepository.new
    action = LinkOwnedProject.new(team_repository: team_repository, project_repository: project_repository)

    result = action.perform(team_id: 'not-found', project_id: '123')

    expect(result.success?).to be(false)
    expect(result.errors).to eq(['team not found'])
  end

  it 'returns failure when project is not found' do
    team = build_team(name: 'My Team', description: '', point_of_contact: '')
    team_repository = FakeTeamRepository.new(teams: { '1' => team })
    project_repository = FakeProjectRepository.new
    action = LinkOwnedProject.new(team_repository: team_repository, project_repository: project_repository)

    result = action.perform(team_id: '1', project_id: 'not-found')

    expect(result.success?).to be(false)
    expect(result.errors).to eq(['project not found'])
  end

  it 'returns failure when team has subordinate teams' do
    team = build_team(name: 'My Team', description: '', point_of_contact: '')
    child_team = build_team(name: 'Child Team')
    project = Project.new(attributes: ProjectAttributes.new(name: 'My Project', description: '', point_of_contact: ''))
    team_repository = FakeTeamRepository.new(teams: { '1' => team, 'child' => child_team })
    team_repository.link_subordinate_team(parent_id: '1', child: child_team, order: 0)
    project_repository = FakeProjectRepository.new(projects: { '99' => project })
    action = LinkOwnedProject.new(team_repository: team_repository, project_repository: project_repository)

    result = action.perform(team_id: '1', project_id: '99')

    expect(result.success?).to be(false)
    expect(result.errors).to eq(['teams with subordinate teams cannot own projects'])
  end

  it 'links an existing project to the team' do
    team = build_team(name: 'My Team', description: '', point_of_contact: '')
    project = Project.new(attributes: ProjectAttributes.new(name: 'My Project', description: '', point_of_contact: ''))
    team_repository = FakeTeamRepository.new(teams: { '1' => team })
    project_repository = FakeProjectRepository.new(projects: { '99' => project })
    action = LinkOwnedProject.new(team_repository: team_repository, project_repository: project_repository)

    result = action.perform(team_id: '1', project_id: '99')

    expect(result.success?).to be(true)
    expect(result.value.name).to eq('My Project')
  end

  it 'creates the relationship in the repository' do
    team = build_team(name: 'My Team', description: '', point_of_contact: '')
    project = Project.new(attributes: ProjectAttributes.new(name: 'My Project', description: '', point_of_contact: ''))
    team_repository = FakeTeamRepository.new(teams: { '1' => team })
    project_repository = FakeProjectRepository.new(projects: { '99' => project })
    action = LinkOwnedProject.new(team_repository: team_repository, project_repository: project_repository)

    action.perform(team_id: '1', project_id: '99')

    relationships = team_repository.owned_relationships_for(team_id: '1')
    expect(relationships.size).to eq(1)
    expect(relationships.first[:project].name).to eq('My Project')
    expect(relationships.first[:order]).to eq(0)
  end

  it 'assigns the next order value when linking' do
    team = build_team(name: 'My Team', description: '', point_of_contact: '')
    first_project = Project.new(attributes: ProjectAttributes.new(name: 'First Project', description: '', point_of_contact: ''))
    second_project = Project.new(attributes: ProjectAttributes.new(name: 'Second Project', description: '', point_of_contact: ''))
    team_repository = FakeTeamRepository.new(teams: { '1' => team })
    project_repository = FakeProjectRepository.new(projects: { '1' => first_project, '2' => second_project })
    action = LinkOwnedProject.new(team_repository: team_repository, project_repository: project_repository)

    action.perform(team_id: '1', project_id: '1')
    action.perform(team_id: '1', project_id: '2')

    relationships = team_repository.owned_relationships_for(team_id: '1')
    expect(relationships.map { |r| r[:order] }).to eq([0, 1])
  end
end
