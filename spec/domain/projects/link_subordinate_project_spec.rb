require 'spec_helper'
require 'domain/projects/link_subordinate_project'
require 'domain/projects/project'
require 'domain/projects/project_attributes'
require 'support/persistence/fake_project_repository'

RSpec.describe LinkSubordinateProject do
  def build_project(name)
    attrs = ProjectAttributes.new(name: name)
    Project.new(attributes: attrs)
  end

  it 'fails when the parent project cannot be found' do
    child = build_project('Child')
    project_repository = FakeProjectRepository.new(projects: { '2' => child })

    action = described_class.new(project_repository: project_repository)

    result = action.perform(parent_id: 'missing', child_id: '2')

    expect(result.success?).to be(false)
    expect(result.errors).to include('parent project not found')
  end

  it 'fails when the child project cannot be found' do
    parent = build_project('Parent')
    project_repository = FakeProjectRepository.new(projects: { '1' => parent })

    action = described_class.new(project_repository: project_repository)

    result = action.perform(parent_id: '1', child_id: 'missing')

    expect(result.success?).to be(false)
    expect(result.errors).to include('child project not found')
  end

  it 'fails when the child already has a parent' do
    parent1 = build_project('Parent1')
    parent2 = build_project('Parent2')
    child = build_project('Child')
    project_repository = FakeProjectRepository.new(projects: { '1' => parent1, '2' => parent2, '3' => child })
    project_repository.link_subordinate(parent_id: '1', child_id: '3', order: 0)

    action = described_class.new(project_repository: project_repository)

    result = action.perform(parent_id: '2', child_id: '3')

    expect(result.success?).to be(false)
    expect(result.errors).to include('project already has a parent')
  end

  it 'links an existing project as a child' do
    parent = build_project('Parent')
    child = build_project('Child')
    project_repository = FakeProjectRepository.new(projects: { '1' => parent, '2' => child })

    action = described_class.new(project_repository: project_repository)

    result = action.perform(parent_id: '1', child_id: '2')

    expect(result.success?).to be(true)
    expect(project_repository.subordinate_exists?(parent_id: '1', child_id: '2')).to be(true)
  end

  it 'returns the child project on success' do
    parent = build_project('Parent')
    child = build_project('Child')
    project_repository = FakeProjectRepository.new(projects: { '1' => parent, '2' => child })

    action = described_class.new(project_repository: project_repository)

    result = action.perform(parent_id: '1', child_id: '2')

    expect(result.value.name).to eq('Child')
  end
end
