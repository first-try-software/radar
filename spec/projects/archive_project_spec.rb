require 'spec_helper'
require_relative '../../domain/projects/archive_project'
require_relative '../../domain/projects/project'

RSpec.describe ArchiveProject do
  class ArchiveProjectRepository
    attr_reader :records

    def initialize
      @records = {}
    end

    def add(id:, project:)
      records[id] = project
    end

    def find(id)
      records[id]
    end

    def save(id:, project:)
      records[id] = project
    end
  end

  it 'looks up the project by id' do
    repository = ArchiveProjectRepository.new
    action = described_class.new(project_repository: repository)

    expect(repository).to receive(:find).with('123').and_return(Project.new(name: 'Status'))

    action.perform(id: '123')
  end

  it 'toggles the archived flag and saves the project' do
    repository = ArchiveProjectRepository.new
    repository.add(id: '123', project: Project.new(name: 'Status'))
    action = described_class.new(project_repository: repository)

    action.perform(id: '123')

    stored_project = repository.records['123']
    expect(stored_project).to be_archived
  end

  it 'returns a successful result when the project is archived' do
    repository = ArchiveProjectRepository.new
    repository.add(id: '123', project: Project.new(name: 'Status'))
    action = described_class.new(project_repository: repository)

    result = action.perform(id: '123')

    expect(result.success?).to be(true)
  end

  it 'returns the archived project as the result value' do
    repository = ArchiveProjectRepository.new
    repository.add(id: '123', project: Project.new(name: 'Status'))
    action = described_class.new(project_repository: repository)

    result = action.perform(id: '123')

    expect(result.value).to be_archived
  end

  it 'returns no errors when the project is archived' do
    repository = ArchiveProjectRepository.new
    repository.add(id: '123', project: Project.new(name: 'Status'))
    action = described_class.new(project_repository: repository)

    result = action.perform(id: '123')

    expect(result.errors).to eq([])
  end

  it 'returns a failure result when the project is not found' do
    repository = ArchiveProjectRepository.new
    action = described_class.new(project_repository: repository)

    result = action.perform(id: 'missing')

    expect(result.success?).to be(false)
  end

  it 'returns errors when the project is not found' do
    repository = ArchiveProjectRepository.new
    action = described_class.new(project_repository: repository)

    result = action.perform(id: 'missing')

    expect(result.errors).to eq(['project not found'])
  end
end
