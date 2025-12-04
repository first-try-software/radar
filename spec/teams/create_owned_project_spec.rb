require 'spec_helper'
require_relative '../../domain/teams/create_owned_project'
require_relative '../../domain/teams/team'
require_relative '../../domain/projects/project'

RSpec.describe CreateOwnedProject do
  class CreateOwnedProjectTeamRepository
    attr_reader :teams, :relationships

    def initialize(teams: {})
      @teams = teams
      @relationships = []
    end

    def find(id)
      teams[id]
    end

    def link_owned_project(team_id:, project:, order:)
      relationships << { team_id:, project:, order: }
    end

    def next_owned_project_order(team_id:)
      max = relationships.select { |rel| rel[:team_id] == team_id }.map { |rel| rel[:order] }.max
      max ? max + 1 : 0
    end
  end

  class CreateOwnedProjectProjectRepository
    attr_reader :projects

    def initialize(existing: [])
      @projects = existing
    end

    def save(project)
      projects << project
    end

    def exists_with_name?(name)
      projects.any? { |project| project.name == name }
    end
  end

  it 'fails when the team cannot be found' do
    team_repository = CreateOwnedProjectTeamRepository.new
    project_repository = CreateOwnedProjectProjectRepository.new
    action = described_class.new(team_repository: team_repository, project_repository: project_repository)

    result = action.perform(team_id: 'team-123', name: 'Project')

    expect(result.success?).to be(false)
    expect(result.errors).to eq(['team not found'])
  end

  it 'fails when the project is invalid' do
    team = Team.new(name: 'Platform')
    team_repository = CreateOwnedProjectTeamRepository.new(teams: { 'team-123' => team })
    project_repository = CreateOwnedProjectProjectRepository.new
    action = described_class.new(team_repository: team_repository, project_repository: project_repository)

    result = action.perform(team_id: 'team-123', name: '')

    expect(result.success?).to be(false)
    expect(result.errors).to eq(['name must be present'])
  end

  it 'fails when the project name already exists' do
    team = Team.new(name: 'Platform')
    team_repository = CreateOwnedProjectTeamRepository.new(teams: { 'team-123' => team })
    project_repository = CreateOwnedProjectProjectRepository.new(existing: [Project.new(name: 'Project')])
    action = described_class.new(team_repository: team_repository, project_repository: project_repository)

    result = action.perform(team_id: 'team-123', name: 'Project')

    expect(result.success?).to be(false)
    expect(result.errors).to eq(['project name must be unique'])
  end

  it 'saves the project and links it to the team' do
    team = Team.new(name: 'Platform')
    team_repository = CreateOwnedProjectTeamRepository.new(teams: { 'team-123' => team })
    project_repository = CreateOwnedProjectProjectRepository.new
    action = described_class.new(team_repository: team_repository, project_repository: project_repository)

    result = action.perform(
      team_id: 'team-123',
      name: 'Status',
      description: 'Status dashboard',
      point_of_contact: 'Alex'
    )

    expect(result.success?).to be(true)
    project = project_repository.projects.first
    expect(project.name).to eq('Status')
    expect(team_repository.relationships.first[:team_id]).to eq('team-123')
    expect(team_repository.relationships.first[:order]).to eq(0)
  end
end
