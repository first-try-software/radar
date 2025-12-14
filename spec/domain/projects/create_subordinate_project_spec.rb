require 'spec_helper'
require 'domain/projects/create_subordinate_project'
require 'domain/projects/project'
require_relative '../../support/persistence/fake_project_repository'
require_relative '../../support/project_builder'

RSpec.describe CreateSubordinateProject do
  it 'returns an error when the parent project cannot be found' do
    repository = FakeProjectRepository.new
    action = described_class.new(project_repository: repository)

    result = action.perform(parent_id: '123', name: 'Child')

    expect(result.success?).to be(false)
    expect(result.errors).to eq(['project not found'])
  end

  it 'returns an error when the subordinate project is invalid' do
    parent = ProjectBuilder.build(name: 'Parent')
    repository = FakeProjectRepository.new(projects: { '123' => parent })
    action = described_class.new(project_repository: repository)

    result = action.perform(parent_id: '123', name: '')

    expect(result.success?).to be(false)
    expect(result.errors).to eq(['name must be present'])
  end

  it 'returns an error when the subordinate project name already exists' do
    parent = ProjectBuilder.build(name: 'Parent')
    repository = FakeProjectRepository.new(
      projects: { '123' => parent, '456' => ProjectBuilder.build(name: 'Child') }
    )
    action = described_class.new(project_repository: repository)

    result = action.perform(parent_id: '123', name: 'Child')

    expect(result.success?).to be(false)
    expect(result.errors).to eq(['project name must be unique'])
  end

  it 'adds the subordinate project to the parent and repository' do
    parent = ProjectBuilder.build(name: 'Parent')
    repository = FakeProjectRepository.new(projects: { '123' => parent })
    action = described_class.new(project_repository: repository)

    result = action.perform(
      parent_id: '123',
      name: 'New Child',
      description: 'Sub project',
      point_of_contact: 'Alex'
    )

    expect(result.success?).to be(true)
    subordinate = repository.find('New Child')
    expect(subordinate.name).to eq('New Child')

    relationship = repository.subordinate_relationships_for(parent_id: '123').first
    expect(relationship[:parent_id]).to eq('123')
    expect(relationship[:child].name).to eq('New Child')
    expect(relationship[:order]).to eq(0)
  end

  it 'rejects duplicate subordinate names that were just persisted' do
    parent = ProjectBuilder.build(name: 'Parent')
    repository = FakeProjectRepository.new(projects: { '123' => parent })
    action = described_class.new(project_repository: repository)

    action.perform(parent_id: '123', name: 'New Child')
    second_attempt = action.perform(parent_id: '123', name: 'New Child')

    expect(second_attempt.success?).to be(false)
    expect(second_attempt.errors).to eq(['project name must be unique'])
  end
end
