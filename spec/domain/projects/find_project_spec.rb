require 'spec_helper'
require 'domain/projects/find_project'
require 'domain/projects/project'
require_relative '../../support/persistence/fake_project_repository'

RSpec.describe FindProject do
  it 'looks up the project by id' do
    repository = FakeProjectRepository.new
    action = described_class.new(project_repository: repository)

    expect(repository).to receive(:find).with('123').and_return(Project.new(name: 'Status'))

    action.perform(id: '123')
  end

  it 'returns a successful result when the project exists' do
    repository = FakeProjectRepository.new
    repository.update(id: '123', project: Project.new(name: 'Status'))
    action = described_class.new(project_repository: repository)

    result = action.perform(id: '123')

    expect(result.success?).to be(true)
  end

  it 'returns the found project as the result value' do
    repository = FakeProjectRepository.new
    repository.update(id: '123', project: Project.new(name: 'Status', description: 'Internal', point_of_contact: 'Alex'))
    action = described_class.new(project_repository: repository)

    result = action.perform(id: '123')

    expect(result.value).to be_a(Project)
  end

  it 'returns no errors when the project exists' do
    repository = FakeProjectRepository.new
    repository.update(id: '123', project: Project.new(name: 'Status'))
    action = described_class.new(project_repository: repository)

    result = action.perform(id: '123')

    expect(result.errors).to eq([])
  end

  it 'returns a failure result when the project does not exist' do
    repository = FakeProjectRepository.new
    action = described_class.new(project_repository: repository)

    result = action.perform(id: 'missing')

    expect(result.success?).to be(false)
  end

  it 'returns errors when the project does not exist' do
    repository = FakeProjectRepository.new
    action = described_class.new(project_repository: repository)

    result = action.perform(id: 'missing')

    expect(result.errors).to eq(['project not found'])
  end
end
