require 'spec_helper'
require 'domain/projects/unarchive_project'
require 'domain/projects/project'
require 'domain/projects/project_attributes'
require 'support/persistence/fake_project_repository'

RSpec.describe UnarchiveProject do
  def build_project(name, archived: true)
    attrs = ProjectAttributes.new(name: name, archived: archived)
    Project.new(attributes: attrs)
  end

  it 'fails when the project cannot be found' do
    project_repository = FakeProjectRepository.new

    action = described_class.new(project_repository: project_repository)

    result = action.perform(id: 'missing')

    expect(result.success?).to be(false)
    expect(result.errors).to include('project not found')
  end

  it 'unarchives the project' do
    project = build_project('Feature A', archived: true)
    project_repository = FakeProjectRepository.new(projects: { '1' => project })

    action = described_class.new(project_repository: project_repository)

    result = action.perform(id: '1')

    expect(result.success?).to be(true)
    expect(result.value.archived?).to be(false)
  end

  it 'persists the unarchived project' do
    project = build_project('Feature A', archived: true)
    project_repository = FakeProjectRepository.new(projects: { '1' => project })

    action = described_class.new(project_repository: project_repository)
    action.perform(id: '1')

    updated = project_repository.find('1')
    expect(updated.archived?).to be(false)
  end
end
