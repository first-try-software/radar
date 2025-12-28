require 'spec_helper'
require 'domain/initiatives/set_initiative_state'
require 'domain/initiatives/initiative'
require 'domain/initiatives/initiative_attributes'
require 'domain/initiatives/initiative_loaders'
require 'support/persistence/fake_initiative_repository'
require 'support/persistence/fake_project_repository'

RSpec.describe SetInitiativeState do
  def build_project(name:, state: :in_progress)
    Project.new(
      attributes: ProjectAttributes.new(name: name, current_state: state),
      loaders: ProjectLoaders.new
    )
  end

  def build_initiative(name:, state: :new, projects: [])
    attrs = InitiativeAttributes.new(name: name, current_state: state)
    loaders = InitiativeLoaders.new(related_projects: ->(_) { projects })
    Initiative.new(attributes: attrs, loaders: loaders)
  end

  it 'updates initiative state' do
    initiative_repo = FakeInitiativeRepository.new
    project_repo = FakeProjectRepository.new
    initiative = build_initiative(name: 'Test Initiative')
    initiative_repo.save(initiative)
    action = described_class.new(initiative_repository: initiative_repo, project_repository: project_repo)

    result = action.perform(id: 'Test Initiative', state: :in_progress)

    expect(result).to be_success
    expect(result.value.current_state).to eq(:in_progress)
  end

  it 'returns failure when initiative not found' do
    initiative_repo = FakeInitiativeRepository.new
    project_repo = FakeProjectRepository.new
    action = described_class.new(initiative_repository: initiative_repo, project_repository: project_repo)

    result = action.perform(id: 'nonexistent', state: :in_progress)

    expect(result).not_to be_success
    expect(result.errors).to include('initiative not found')
  end

  it 'returns failure for invalid state' do
    initiative_repo = FakeInitiativeRepository.new
    project_repo = FakeProjectRepository.new
    initiative = build_initiative(name: 'Test Initiative')
    initiative_repo.save(initiative)
    action = described_class.new(initiative_repository: initiative_repo, project_repository: project_repo)

    result = action.perform(id: 'Test Initiative', state: :invalid)

    expect(result).not_to be_success
    expect(result.errors).to include('invalid state')
  end

  it 'returns failure for nil state' do
    initiative_repo = FakeInitiativeRepository.new
    project_repo = FakeProjectRepository.new
    initiative = build_initiative(name: 'Test Initiative')
    initiative_repo.save(initiative)
    action = described_class.new(initiative_repository: initiative_repo, project_repository: project_repo)

    result = action.perform(id: 'Test Initiative', state: nil)

    expect(result).not_to be_success
    expect(result.errors).to include('invalid state')
  end

  it 'does not cascade by default' do
    initiative_repo = FakeInitiativeRepository.new
    project_repo = FakeProjectRepository.new
    project = build_project(name: 'Related Project', state: :in_progress)
    project_repo.save(project)
    initiative = build_initiative(name: 'Test Initiative', projects: [project])
    initiative_repo.save(initiative)
    action = described_class.new(initiative_repository: initiative_repo, project_repository: project_repo)

    action.perform(id: 'Test Initiative', state: :done)

    updated_project = project_repo.find('Related Project')
    expect(updated_project.current_state).to eq(:in_progress)
  end

  it 'cascades state to projects when cascade is true' do
    initiative_repo = FakeInitiativeRepository.new
    project_repo = FakeProjectRepository.new
    project = build_project(name: 'Related Project', state: :in_progress)
    project_repo.save(project)
    initiative = build_initiative(name: 'Test Initiative', projects: [project])
    initiative_repo.save(initiative)
    action = described_class.new(initiative_repository: initiative_repo, project_repository: project_repo)

    action.perform(id: 'Test Initiative', state: :done, cascade: true)

    updated_project = project_repo.find('Related Project')
    expect(updated_project.current_state).to eq(:done)
  end

  it 'does not cascade non-cascading states even when cascade is true' do
    initiative_repo = FakeInitiativeRepository.new
    project_repo = FakeProjectRepository.new
    project = build_project(name: 'Related Project', state: :todo)
    project_repo.save(project)
    initiative = build_initiative(name: 'Test Initiative', projects: [project])
    initiative_repo.save(initiative)
    action = described_class.new(initiative_repository: initiative_repo, project_repository: project_repo)

    action.perform(id: 'Test Initiative', state: :in_progress, cascade: true)

    updated_project = project_repo.find('Related Project')
    expect(updated_project.current_state).to eq(:todo)
  end
end
