require 'spec_helper'
require_relative '../../domain/projects/create_project'
require_relative '../../domain/projects/project'

RSpec.describe CreateProject do
  class CreateProjectRepository
    attr_reader :records

    def initialize
      @records = []
    end

    def save(project)
      records << project
    end
  end

  it 'stores the created project in the provided repository' do
    repository = CreateProjectRepository.new
    action = described_class.new(project_repository: repository)

    action.perform(name: 'Status', description: 'Status dashboard', point_of_contact: 'Alex')

    stored_project = repository.records.first
    expect(stored_project.name).to eq('Status')
  end

  it 'returns a successful result' do
    repository = CreateProjectRepository.new
    action = described_class.new(project_repository: repository)

    result = action.perform(name: 'Status')

    expect(result.success?).to be(true)
  end

  it 'returns the stored project as the result value' do
    repository = CreateProjectRepository.new
    action = described_class.new(project_repository: repository)

    result = action.perform(name: 'Status')

    expect(result.value).to be_a(Project)
  end

  it 'returns no errors on success' do
    repository = CreateProjectRepository.new
    action = described_class.new(project_repository: repository)

    result = action.perform(name: 'Status')

    expect(result.errors).to eq([])
  end

  it 'returns a failure result when the project is invalid' do
    repository = CreateProjectRepository.new
    action = described_class.new(project_repository: repository)

    result = action.perform(name: '')

    expect(result.success?).to be(false)
  end

  it 'does not store a project when it is invalid' do
    repository = CreateProjectRepository.new
    action = described_class.new(project_repository: repository)

    action.perform(name: '')

    expect(repository.records).to be_empty
  end

  it 'returns a descriptive validation error' do
    repository = CreateProjectRepository.new
    action = described_class.new(project_repository: repository)

    result = action.perform(name: '')

    expect(result.errors).to eq(['name must be present'])
  end
end
