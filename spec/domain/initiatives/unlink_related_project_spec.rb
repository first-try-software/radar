require 'spec_helper'
require 'domain/initiatives/unlink_related_project'
require 'domain/initiatives/initiative'
require 'domain/projects/project'
require 'domain/projects/project_attributes'
require 'support/persistence/fake_initiative_repository'
require 'support/persistence/fake_project_repository'

RSpec.describe UnlinkRelatedProject do
  def build_project(name)
    attrs = ProjectAttributes.new(name: name)
    Project.new(attributes: attrs)
  end

  it 'fails when the initiative cannot be found' do
    initiative_repository = FakeInitiativeRepository.new

    action = described_class.new(initiative_repository: initiative_repository)

    result = action.perform(initiative_id: 'missing', project_id: 'Feature A')

    expect(result.success?).to be(false)
    expect(result.errors).to include('initiative not found')
  end

  it 'fails when the project is not linked to the initiative' do
    initiative = Initiative.new(name: 'Launch 2025')
    initiative_repository = FakeInitiativeRepository.new(initiatives: { '1' => initiative })

    action = described_class.new(initiative_repository: initiative_repository)

    result = action.perform(initiative_id: '1', project_id: 'Feature A')

    expect(result.success?).to be(false)
    expect(result.errors).to include('project not linked to initiative')
  end

  it 'unlinks an existing project from the initiative' do
    initiative = Initiative.new(name: 'Launch 2025')
    initiative_repository = FakeInitiativeRepository.new(initiatives: { '1' => initiative })
    project = build_project('Feature A')
    initiative_repository.link_related_project(initiative_id: '1', project: project, order: 0)

    action = described_class.new(initiative_repository: initiative_repository)

    result = action.perform(initiative_id: '1', project_id: 'Feature A')

    expect(result.success?).to be(true)
    relationships = initiative_repository.related_projects_for(initiative_id: '1')
    expect(relationships).to be_empty
  end

  it 'returns the initiative on success' do
    initiative = Initiative.new(name: 'Launch 2025')
    initiative_repository = FakeInitiativeRepository.new(initiatives: { '1' => initiative })
    project = build_project('Feature A')
    initiative_repository.link_related_project(initiative_id: '1', project: project, order: 0)

    action = described_class.new(initiative_repository: initiative_repository)

    result = action.perform(initiative_id: '1', project_id: 'Feature A')

    expect(result.value.name).to eq('Launch 2025')
  end
end
