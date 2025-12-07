require 'spec_helper'
require 'domain/projects/set_project_state'
require 'domain/projects/project'
require_relative '../../support/persistence/fake_project_repository'

RSpec.describe SetProjectState do
  it 'fails when the project cannot be found' do
    repository = FakeProjectRepository.new
    action = described_class.new(project_repository: repository)

    result = action.perform(id: '123', state: :todo)

    expect(result.success?).to be(false)
    expect(result.errors).to eq(['project not found'])
  end

  it 'fails when an invalid state is provided' do
    project = Project.new(name: 'Status')
    repository = FakeProjectRepository.new(projects: { '123' => project })
    action = described_class.new(project_repository: repository)

    result = action.perform(id: '123', state: :invalid)

    expect(result.success?).to be(false)
    expect(result.errors).to eq(['invalid state'])
  end

  it 'fails when the transition is not allowed' do
    project = Project.new(name: 'Status')
    repository = FakeProjectRepository.new(projects: { '123' => project })
    action = described_class.new(project_repository: repository)

    result = action.perform(id: '123', state: :blocked)

    expect(result.success?).to be(false)
    expect(result.errors).to eq(['invalid state transition'])
  end

  it 'fails when the project is already done' do
    project = Project.new(name: 'Status', current_state: :done)
    repository = FakeProjectRepository.new(projects: { '123' => project })
    action = described_class.new(project_repository: repository)

    result = action.perform(id: '123', state: :todo)

    expect(result.success?).to be(false)
    expect(result.errors).to eq(['invalid state transition'])
  end

  it 'updates the project state when valid' do
    project = Project.new(name: 'Status', current_state: :new)
    repository = FakeProjectRepository.new(projects: { '123' => project })
    action = described_class.new(project_repository: repository)

    result = action.perform(id: '123', state: :todo)

    expect(result.success?).to be(true)
    saved = repository.find('123')
    expect(saved.current_state).to eq(:todo)
  end
end
