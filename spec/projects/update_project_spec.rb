require 'spec_helper'
require_relative '../../domain/projects/update_project'
require_relative '../../domain/projects/project'

RSpec.describe UpdateProject do
  class UpdateProjectRepository
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

  it 'looks up the existing project by id' do
    repository = UpdateProjectRepository.new
    action = described_class.new(project_repository: repository)

    expect(repository).to receive(:find).with('123').and_return(Project.new(name: 'Old'))

    action.perform(id: '123', name: 'New')
  end

  it 'stores the new project over the existing record' do
    repository = UpdateProjectRepository.new
    repository.add(id: '123', project: Project.new(name: 'Old'))
    action = described_class.new(project_repository: repository)

    action.perform(id: '123', name: 'New', description: 'Updated', point_of_contact: 'Jordan')

    stored_project = repository.records['123']
    expect(stored_project.name).to eq('New')
  end

  it 'returns a successful result when the update succeeds' do
    repository = UpdateProjectRepository.new
    repository.add(id: '123', project: Project.new(name: 'Old'))
    action = described_class.new(project_repository: repository)

    result = action.perform(id: '123', name: 'New')

    expect(result.success?).to be(true)
  end

  it 'returns the updated project as the result value' do
    repository = UpdateProjectRepository.new
    repository.add(id: '123', project: Project.new(name: 'Old'))
    action = described_class.new(project_repository: repository)

    result = action.perform(id: '123', name: 'New')

    expect(result.value).to be_a(Project)
  end

  it 'returns no errors when the update succeeds' do
    repository = UpdateProjectRepository.new
    repository.add(id: '123', project: Project.new(name: 'Old'))
    action = described_class.new(project_repository: repository)

    result = action.perform(id: '123', name: 'New')

    expect(result.errors).to eq([])
  end

  it 'returns a failure result when the project cannot be found' do
    repository = UpdateProjectRepository.new
    action = described_class.new(project_repository: repository)

    result = action.perform(id: 'missing', name: 'New')

    expect(result.success?).to be(false)
  end

  it 'returns errors when the project cannot be found' do
    repository = UpdateProjectRepository.new
    action = described_class.new(project_repository: repository)

    result = action.perform(id: 'missing', name: 'New')

    expect(result.errors).to eq(['project not found'])
  end

  it 'returns a failure result when the new project is invalid' do
    repository = UpdateProjectRepository.new
    repository.add(id: '123', project: Project.new(name: 'Old'))
    action = described_class.new(project_repository: repository)

    result = action.perform(id: '123', name: '')

    expect(result.success?).to be(false)
  end

  it 'does not store a new project when it is invalid' do
    repository = UpdateProjectRepository.new
    repository.add(id: '123', project: Project.new(name: 'Old'))
    action = described_class.new(project_repository: repository)

    action.perform(id: '123', name: '')

    expect(repository.records['123'].name).to eq('Old')
  end

  it 'returns validation errors when the new project is invalid' do
    repository = UpdateProjectRepository.new
    repository.add(id: '123', project: Project.new(name: 'Old'))
    action = described_class.new(project_repository: repository)

    result = action.perform(id: '123', name: '')

    expect(result.errors).to eq(['name must be present'])
  end
end
