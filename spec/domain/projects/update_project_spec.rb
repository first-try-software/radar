require 'spec_helper'
require 'domain/projects/update_project'
require 'domain/projects/project'
require_relative '../../support/persistence/fake_project_repository'
require_relative '../../support/project_builder'

RSpec.describe UpdateProject do
  it 'looks up the existing project by id' do
    repository = FakeProjectRepository.new
    action = described_class.new(project_repository: repository)

    expect(repository).to receive(:find).with('123').and_return(ProjectBuilder.build(name: 'Old'))

    action.perform(id: '123', name: 'New')
  end

  it 'stores the new project over the existing record' do
    repository = FakeProjectRepository.new
    repository.update(id: '123', project: ProjectBuilder.build(name: 'Old'))
    action = described_class.new(project_repository: repository)

    action.perform(id: '123', name: 'New', description: 'Updated', point_of_contact: 'Jordan')

    stored_project = repository.find('123')
    expect(stored_project.name).to eq('New')
  end

  it 'returns a successful result when the update succeeds' do
    repository = FakeProjectRepository.new
    repository.update(id: '123', project: ProjectBuilder.build(name: 'Old'))
    action = described_class.new(project_repository: repository)

    result = action.perform(id: '123', name: 'New')

    expect(result.success?).to be(true)
  end

  it 'returns the updated project as the result value' do
    repository = FakeProjectRepository.new
    repository.update(id: '123', project: ProjectBuilder.build(name: 'Old'))
    action = described_class.new(project_repository: repository)

    result = action.perform(id: '123', name: 'New')

    expect(result.value).to be_a(Project)
  end

  it 'returns no errors when the update succeeds' do
    repository = FakeProjectRepository.new
    repository.update(id: '123', project: ProjectBuilder.build(name: 'Old'))
    action = described_class.new(project_repository: repository)

    result = action.perform(id: '123', name: 'New')

    expect(result.errors).to eq([])
  end

  it 'succeeds when the name is unchanged' do
    repository = FakeProjectRepository.new
    repository.update(id: '123', project: ProjectBuilder.build(name: 'Status'))
    action = described_class.new(project_repository: repository)

    result = action.perform(id: '123', name: 'Status')

    expect(result.success?).to be(true)
    expect(result.errors).to eq([])
  end

  it 'returns a failure result when the project cannot be found' do
    repository = FakeProjectRepository.new
    action = described_class.new(project_repository: repository)

    result = action.perform(id: 'missing', name: 'New')

    expect(result.success?).to be(false)
  end

  it 'returns errors when the project cannot be found' do
    repository = FakeProjectRepository.new
    action = described_class.new(project_repository: repository)

    result = action.perform(id: 'missing', name: 'New')

    expect(result.errors).to eq(['project not found'])
  end

  it 'returns a failure result when the new project is invalid' do
    repository = FakeProjectRepository.new
    repository.update(id: '123', project: ProjectBuilder.build(name: 'Old'))
    action = described_class.new(project_repository: repository)

    result = action.perform(id: '123', name: '')

    expect(result.success?).to be(false)
  end

  it 'does not store a new project when it is invalid' do
    repository = FakeProjectRepository.new
    repository.update(id: '123', project: ProjectBuilder.build(name: 'Old'))
    action = described_class.new(project_repository: repository)

    action.perform(id: '123', name: '')

    expect(repository.find('123').name).to eq('Old')
  end

  it 'returns validation errors when the new project is invalid' do
    repository = FakeProjectRepository.new
    repository.update(id: '123', project: ProjectBuilder.build(name: 'Old'))
    action = described_class.new(project_repository: repository)

    result = action.perform(id: '123', name: '')

    expect(result.errors).to eq(['name must be present'])
  end

  it 'returns a failure result when the new project name already exists' do
    repository = FakeProjectRepository.new
    repository.update(id: '123', project: ProjectBuilder.build(name: 'Old'))
    repository.update(id: '456', project: ProjectBuilder.build(name: 'Status'))
    action = described_class.new(project_repository: repository)

    result = action.perform(id: '123', name: 'Status')

    expect(result.success?).to be(false)
  end

  it 'returns an error message when the new project name already exists' do
    repository = FakeProjectRepository.new
    repository.update(id: '123', project: ProjectBuilder.build(name: 'Old'))
    repository.update(id: '456', project: ProjectBuilder.build(name: 'Status'))
    action = described_class.new(project_repository: repository)

    result = action.perform(id: '123', name: 'Status')

    expect(result.errors).to eq(['project name must be unique'])
  end

  it 'archives a project when archived is set to true' do
    repository = FakeProjectRepository.new
    repository.update(id: '123', project: ProjectBuilder.build(name: 'Test', archived: false))
    action = described_class.new(project_repository: repository)

    action.perform(id: '123', name: 'Test', archived: true)

    expect(repository.find('123').archived?).to be(true)
  end

  it 'unarchives a project when archived is set to false' do
    repository = FakeProjectRepository.new
    repository.update(id: '123', project: ProjectBuilder.build(name: 'Test', archived: true))
    action = described_class.new(project_repository: repository)

    action.perform(id: '123', name: 'Test', archived: false)

    expect(repository.find('123').archived?).to be(false)
  end

  it 'preserves archived status when archived is not provided' do
    repository = FakeProjectRepository.new
    repository.update(id: '123', project: ProjectBuilder.build(name: 'Old', archived: true))
    action = described_class.new(project_repository: repository)

    action.perform(id: '123', name: 'New')

    expect(repository.find('123').archived?).to be(true)
  end

  it 'preserves current_state when updating other attributes' do
    repository = FakeProjectRepository.new
    repository.update(id: '123', project: ProjectBuilder.build(name: 'Old', current_state: :in_progress))
    action = described_class.new(project_repository: repository)

    action.perform(id: '123', name: 'New')

    expect(repository.find('123').current_state).to eq(:in_progress)
  end

  it 'preserves existing name when name is not provided' do
    repository = FakeProjectRepository.new
    repository.update(id: '123', project: ProjectBuilder.build(name: 'Old', description: 'Old desc'))
    action = described_class.new(project_repository: repository)

    action.perform(id: '123', description: 'New desc')

    expect(repository.find('123').name).to eq('Old')
    expect(repository.find('123').description).to eq('New desc')
  end

  it 'preserves existing description when description is not provided' do
    repository = FakeProjectRepository.new
    repository.update(id: '123', project: ProjectBuilder.build(name: 'Old', description: 'Old desc'))
    action = described_class.new(project_repository: repository)

    action.perform(id: '123', name: 'New')

    expect(repository.find('123').description).to eq('Old desc')
  end

  it 'preserves existing point_of_contact when not provided' do
    repository = FakeProjectRepository.new
    repository.update(id: '123', project: ProjectBuilder.build(name: 'Old', point_of_contact: 'Jordan'))
    action = described_class.new(project_repository: repository)

    action.perform(id: '123', name: 'New')

    expect(repository.find('123').point_of_contact).to eq('Jordan')
  end

  it 'allows setting description to empty string' do
    repository = FakeProjectRepository.new
    repository.update(id: '123', project: ProjectBuilder.build(name: 'Old', description: 'Old desc'))
    action = described_class.new(project_repository: repository)

    action.perform(id: '123', description: '')

    expect(repository.find('123').description).to eq('')
  end
end
