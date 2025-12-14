require 'spec_helper'
require 'domain/projects/unlink_subordinate_project'
require 'domain/projects/project'
require 'domain/projects/project_attributes'
require 'support/persistence/fake_project_repository'

RSpec.describe UnlinkSubordinateProject do
  def build_project(name)
    attrs = ProjectAttributes.new(name: name)
    Project.new(attributes: attrs)
  end

  it 'fails when the parent project cannot be found' do
    project_repository = FakeProjectRepository.new

    action = described_class.new(project_repository: project_repository)

    result = action.perform(parent_id: 'missing', child_id: 'child')

    expect(result.success?).to be(false)
    expect(result.errors).to include('parent project not found')
  end

  it 'fails when the child is not linked to the parent' do
    parent = build_project('Parent')
    project_repository = FakeProjectRepository.new(projects: { '1' => parent })

    action = described_class.new(project_repository: project_repository)

    result = action.perform(parent_id: '1', child_id: 'nonexistent')

    expect(result.success?).to be(false)
    expect(result.errors).to include('project not linked to parent')
  end

  it 'unlinks a subordinate project from the parent' do
    parent = build_project('Parent')
    child = build_project('Child')
    project_repository = FakeProjectRepository.new(projects: { '1' => parent, '2' => child })
    project_repository.link_subordinate(parent_id: '1', child_id: '2', order: 0)

    action = described_class.new(project_repository: project_repository)

    result = action.perform(parent_id: '1', child_id: '2')

    expect(result.success?).to be(true)
    expect(project_repository.subordinate_exists?(parent_id: '1', child_id: '2')).to be(false)
  end

  it 'returns the parent project on success' do
    parent = build_project('Parent')
    child = build_project('Child')
    project_repository = FakeProjectRepository.new(projects: { '1' => parent, '2' => child })
    project_repository.link_subordinate(parent_id: '1', child_id: '2', order: 0)

    action = described_class.new(project_repository: project_repository)

    result = action.perform(parent_id: '1', child_id: '2')

    expect(result.value.name).to eq('Parent')
  end
end
