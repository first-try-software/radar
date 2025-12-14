require 'spec_helper'
require 'domain/projects/archive_project'
require 'domain/projects/project'
require_relative '../../support/persistence/fake_project_repository'
require_relative '../../support/project_builder'

RSpec.describe ArchiveProject do
  it 'looks up the project by id' do
    repository = FakeProjectRepository.new
    action = described_class.new(project_repository: repository)

    expect(repository).to receive(:find).with('123').and_return(ProjectBuilder.build(name: 'Status'))

    action.perform(id: '123')
  end

  it 'toggles the archived flag and saves the project' do
    repository = FakeProjectRepository.new
    repository.update(id: '123', project: ProjectBuilder.build(name: 'Status'))
    action = described_class.new(project_repository: repository)

    action.perform(id: '123')

    stored_project = repository.find('123')
    expect(stored_project).to be_archived
  end

  it 'returns a successful result when the project is archived' do
    repository = FakeProjectRepository.new
    repository.update(id: '123', project: ProjectBuilder.build(name: 'Status'))
    action = described_class.new(project_repository: repository)

    result = action.perform(id: '123')

    expect(result.success?).to be(true)
  end

  it 'returns the archived project as the result value' do
    repository = FakeProjectRepository.new
    repository.update(id: '123', project: ProjectBuilder.build(name: 'Status'))
    action = described_class.new(project_repository: repository)

    result = action.perform(id: '123')

    expect(result.value).to be_archived
  end

  it 'returns no errors when the project is archived' do
    repository = FakeProjectRepository.new
    repository.update(id: '123', project: ProjectBuilder.build(name: 'Status'))
    action = described_class.new(project_repository: repository)

    result = action.perform(id: '123')

    expect(result.errors).to eq([])
  end

  it 'returns a failure result when the project is not found' do
    repository = FakeProjectRepository.new
    action = described_class.new(project_repository: repository)

    result = action.perform(id: 'missing')

    expect(result.success?).to be(false)
  end

  it 'returns errors when the project is not found' do
    repository = FakeProjectRepository.new
    action = described_class.new(project_repository: repository)

    result = action.perform(id: 'missing')

    expect(result.errors).to eq(['project not found'])
  end
end
