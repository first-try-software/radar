require 'spec_helper'
require_relative '../../domain/initiatives/create_related_project'
require_relative '../../domain/initiatives/initiative'
require_relative '../../domain/projects/project'

RSpec.describe CreateRelatedProject do
  class CreateRelatedProjectInitiativeRepository
    attr_reader :initiatives, :relationships

    def initialize(initiatives: {})
      @initiatives = initiatives
      @relationships = []
    end

    def find(id)
      initiatives[id]
    end

    def link_related_project(initiative_id:, project:, order:)
      relationships << { initiative_id:, project:, order: }
    end

    def next_related_project_order(initiative_id:)
      max = relationships.select { |rel| rel[:initiative_id] == initiative_id }.map { |rel| rel[:order] }.max
      max ? max + 1 : 0
    end
  end

  class CreateRelatedProjectProjectRepository
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

  it 'fails when the initiative cannot be found' do
    initiative_repository = CreateRelatedProjectInitiativeRepository.new
    project_repository = CreateRelatedProjectProjectRepository.new
    action = described_class.new(
      initiative_repository: initiative_repository,
      project_repository: project_repository
    )

    result = action.perform(initiative_id: 'init-123', name: 'Project')

    expect(result.success?).to be(false)
    expect(result.errors).to eq(['initiative not found'])
  end

  it 'fails when the project is invalid' do
    initiative = Initiative.new(name: 'Modernize Infra')
    initiative_repository = CreateRelatedProjectInitiativeRepository.new(initiatives: { 'init-123' => initiative })
    project_repository = CreateRelatedProjectProjectRepository.new
    action = described_class.new(
      initiative_repository: initiative_repository,
      project_repository: project_repository
    )

    result = action.perform(initiative_id: 'init-123', name: '')

    expect(result.success?).to be(false)
    expect(result.errors).to eq(['name must be present'])
  end

  it 'fails when the project name already exists' do
    initiative = Initiative.new(name: 'Modernize Infra')
    initiative_repository = CreateRelatedProjectInitiativeRepository.new(initiatives: { 'init-123' => initiative })
    project_repository = CreateRelatedProjectProjectRepository.new(existing: [Project.new(name: 'Project')])
    action = described_class.new(
      initiative_repository: initiative_repository,
      project_repository: project_repository
    )

    result = action.perform(initiative_id: 'init-123', name: 'Project')

    expect(result.success?).to be(false)
    expect(result.errors).to eq(['project name must be unique'])
  end

  it 'saves the project and links it to the initiative' do
    initiative = Initiative.new(name: 'Modernize Infra')
    initiative_repository = CreateRelatedProjectInitiativeRepository.new(initiatives: { 'init-123' => initiative })
    project_repository = CreateRelatedProjectProjectRepository.new
    action = described_class.new(
      initiative_repository: initiative_repository,
      project_repository: project_repository
    )

    result = action.perform(
      initiative_id: 'init-123',
      name: 'Status',
      description: 'Status dashboard',
      point_of_contact: 'Alex'
    )

    expect(result.success?).to be(true)
    project = project_repository.projects.first
    expect(project.name).to eq('Status')
    relationship = initiative_repository.relationships.first
    expect(relationship[:initiative_id]).to eq('init-123')
    expect(relationship[:order]).to eq(0)
  end
end
