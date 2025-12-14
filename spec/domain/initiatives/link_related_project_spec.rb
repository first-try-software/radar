require 'spec_helper'
require 'domain/initiatives/link_related_project'
require 'domain/initiatives/initiative'
require 'domain/projects/project'
require 'domain/projects/project_attributes'
require 'support/persistence/fake_initiative_repository'
require 'support/persistence/fake_project_repository'

RSpec.describe LinkRelatedProject do
  def build_project(name)
    attrs = ProjectAttributes.new(name: name)
    Project.new(attributes: attrs)
  end

  it 'fails when the initiative cannot be found' do
    initiative_repository = FakeInitiativeRepository.new
    project_repository = FakeProjectRepository.new
    project = build_project('Feature A')
    project_repository.save(project)

    action = described_class.new(
      initiative_repository: initiative_repository,
      project_repository: project_repository
    )

    result = action.perform(initiative_id: 'missing', project_id: 'Feature A')

    expect(result.success?).to be(false)
    expect(result.errors).to include('initiative not found')
  end

  it 'fails when the project cannot be found' do
    initiative = Initiative.new(name: 'Launch 2025')
    initiative_repository = FakeInitiativeRepository.new(initiatives: { '1' => initiative })
    project_repository = FakeProjectRepository.new

    action = described_class.new(
      initiative_repository: initiative_repository,
      project_repository: project_repository
    )

    result = action.perform(initiative_id: '1', project_id: 'missing')

    expect(result.success?).to be(false)
    expect(result.errors).to include('project not found')
  end

  it 'links an existing project to the initiative' do
    initiative = Initiative.new(name: 'Launch 2025')
    initiative_repository = FakeInitiativeRepository.new(initiatives: { '1' => initiative })
    project_repository = FakeProjectRepository.new
    project = build_project('Feature A')
    project_repository.save(project)

    action = described_class.new(
      initiative_repository: initiative_repository,
      project_repository: project_repository
    )

    result = action.perform(initiative_id: '1', project_id: 'Feature A')

    expect(result.success?).to be(true)
    expect(result.value.name).to eq('Feature A')
    relationships = initiative_repository.related_projects_for(initiative_id: '1')
    expect(relationships.length).to eq(1)
    expect(relationships.first[:project].name).to eq('Feature A')
  end

  it 'assigns order to linked projects incrementally' do
    initiative = Initiative.new(name: 'Launch 2025')
    initiative_repository = FakeInitiativeRepository.new(initiatives: { '1' => initiative })
    project_repository = FakeProjectRepository.new
    project_a = build_project('Feature A')
    project_b = build_project('Feature B')
    project_repository.save(project_a)
    project_repository.save(project_b)

    action = described_class.new(
      initiative_repository: initiative_repository,
      project_repository: project_repository
    )

    action.perform(initiative_id: '1', project_id: 'Feature A')
    action.perform(initiative_id: '1', project_id: 'Feature B')

    relationships = initiative_repository.related_projects_for(initiative_id: '1')
    expect(relationships.map { |r| r[:order] }).to eq([0, 1])
  end
end
