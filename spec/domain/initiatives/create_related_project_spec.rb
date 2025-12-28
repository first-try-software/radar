require 'spec_helper'
require 'domain/initiatives/create_related_project'
require_relative '../../support/domain/initiative_builder'
require_relative '../../support/persistence/fake_initiative_repository'
require_relative '../../support/persistence/fake_project_repository'
require_relative '../../support/project_builder'

RSpec.describe CreateRelatedProject do
  include InitiativeBuilder

  it 'fails when the initiative cannot be found' do
    initiative_repository = FakeInitiativeRepository.new
    project_repository = FakeProjectRepository.new
    action = described_class.new(
      initiative_repository: initiative_repository,
      project_repository: project_repository
    )

    result = action.perform(initiative_id: 'init-123', name: 'Project')

    expect(result.success?).to be(false)
    expect(result.errors).to eq(['initiative not found'])
  end

  it 'fails when the project is invalid' do
    initiative = build_initiative(name: 'Modernize Infra')
    initiative_repository = FakeInitiativeRepository.new(initiatives: { 'init-123' => initiative })
    project_repository = FakeProjectRepository.new
    action = described_class.new(
      initiative_repository: initiative_repository,
      project_repository: project_repository
    )

    result = action.perform(initiative_id: 'init-123', name: '')

    expect(result.success?).to be(false)
    expect(result.errors).to eq(['name must be present'])
  end

  it 'fails when the project name already exists' do
    initiative = build_initiative(name: 'Modernize Infra')
    initiative_repository = FakeInitiativeRepository.new(initiatives: { 'init-123' => initiative })
    project_repository = FakeProjectRepository.new
    project_repository.save(ProjectBuilder.build(name: 'Project'))
    action = described_class.new(
      initiative_repository: initiative_repository,
      project_repository: project_repository
    )

    result = action.perform(initiative_id: 'init-123', name: 'Project')

    expect(result.success?).to be(false)
    expect(result.errors).to eq(['project name must be unique'])
  end

  it 'saves the project and links it to the initiative' do
    initiative = build_initiative(name: 'Modernize Infra')
    initiative_repository = FakeInitiativeRepository.new(initiatives: { 'init-123' => initiative })
    project_repository = FakeProjectRepository.new
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
    project = project_repository.find('Status')
    expect(project.name).to eq('Status')
    relationship = initiative_repository.related_projects_for(initiative_id: 'init-123').first
    expect(relationship[:initiative_id]).to eq('init-123')
    expect(relationship[:order]).to eq(0)
  end
end
