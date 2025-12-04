require 'spec_helper'
require_relative '../../domain/projects/set_project_state'
require_relative '../../domain/projects/project'

RSpec.describe SetProjectState do
  class SetProjectStateRepository
    attr_reader :stored

    def initialize(projects: {})
      @projects = projects
      @stored = {}
    end

    def find(id)
      @projects[id]
    end

    def save(id:, project:)
      stored[id] = project
    end
  end

  it 'fails when the project cannot be found' do
    repository = SetProjectStateRepository.new
    action = described_class.new(project_repository: repository)

    result = action.perform(id: '123', state: :todo)

    expect(result.success?).to be(false)
    expect(result.errors).to eq(['project not found'])
  end

  it 'fails when an invalid state is provided' do
    project = Project.new(name: 'Status')
    repository = SetProjectStateRepository.new(projects: { '123' => project })
    action = described_class.new(project_repository: repository)

    result = action.perform(id: '123', state: :invalid)

    expect(result.success?).to be(false)
    expect(result.errors).to eq(['invalid state'])
  end

  it 'fails when the transition is not allowed' do
    project = Project.new(name: 'Status')
    repository = SetProjectStateRepository.new(projects: { '123' => project })
    action = described_class.new(project_repository: repository)

    result = action.perform(id: '123', state: :blocked)

    expect(result.success?).to be(false)
    expect(result.errors).to eq(['invalid state transition'])
  end

  it 'fails when the project is already done' do
    project = Project.new(name: 'Status', current_state: :done)
    repository = SetProjectStateRepository.new(projects: { '123' => project })
    action = described_class.new(project_repository: repository)

    result = action.perform(id: '123', state: :todo)

    expect(result.success?).to be(false)
    expect(result.errors).to eq(['invalid state transition'])
  end

  it 'updates the project state when valid' do
    project = Project.new(name: 'Status', current_state: :new)
    repository = SetProjectStateRepository.new(projects: { '123' => project })
    action = described_class.new(project_repository: repository)

    result = action.perform(id: '123', state: :todo)

    expect(result.success?).to be(true)
    saved = repository.stored['123']
    expect(saved.current_state).to eq(:todo)
  end
end
