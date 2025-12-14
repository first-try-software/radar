require 'spec_helper'
require 'domain/projects/create_project'
require 'domain/projects/project'
require_relative '../../support/persistence/fake_project_repository'
require_relative '../../support/project_builder'

RSpec.describe CreateProject do
  it 'stores the created project in the provided repository' do
    repository = FakeProjectRepository.new
    action = described_class.new(project_repository: repository)

    action.perform(name: 'Status', description: 'Status dashboard', point_of_contact: 'Alex')

    stored_project = repository.find('Status')
    expect(stored_project.name).to eq('Status')
  end

  it 'returns a successful result' do
    repository = FakeProjectRepository.new
    action = described_class.new(project_repository: repository)

    result = action.perform(name: 'Status')

    expect(result.success?).to be(true)
  end

  it 'returns the stored project as the result value' do
    repository = FakeProjectRepository.new
    action = described_class.new(project_repository: repository)

    result = action.perform(name: 'Status')

    expect(result.value).to be_a(Project)
  end

  it 'returns no errors on success' do
    repository = FakeProjectRepository.new
    action = described_class.new(project_repository: repository)

    result = action.perform(name: 'Status')

    expect(result.errors).to eq([])
  end

  it 'returns a failure result when the project is invalid' do
    repository = FakeProjectRepository.new
    action = described_class.new(project_repository: repository)

    result = action.perform(name: '')

    expect(result.success?).to be(false)
  end

  it 'does not store a project when it is invalid' do
    repository = FakeProjectRepository.new
    action = described_class.new(project_repository: repository)

    action.perform(name: '')

    expect(repository.exists_with_name?('')).to be(false)
  end

  it 'returns a descriptive validation error' do
    repository = FakeProjectRepository.new
    action = described_class.new(project_repository: repository)

    result = action.perform(name: '')

    expect(result.errors).to eq(['name must be present'])
  end

  it 'returns a failure result when the project name already exists' do
    repository = FakeProjectRepository.new
    repository.save(ProjectBuilder.build(name: 'Status'))
    action = described_class.new(project_repository: repository)

    result = action.perform(name: 'Status')

    expect(result.success?).to be(false)
  end

  it 'returns an error message when the project name already exists' do
    repository = FakeProjectRepository.new
    repository.save(ProjectBuilder.build(name: 'Status'))
    action = described_class.new(project_repository: repository)

    result = action.perform(name: 'Status')

    expect(result.errors).to eq(['project name must be unique'])
  end
end
