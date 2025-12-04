require 'spec_helper'
require_relative '../../../domain/projects/find_project'
require_relative '../../../domain/projects/project'

RSpec.describe FindProject do
  class FindProjectRepository
    def initialize
      @records = {}
    end

    def add(id:, name:, description: '', point_of_contact: '')
      project = Project.new(name: name, description: description, point_of_contact: point_of_contact)
      records[id] = project
    end

    def find(id)
      records[id]
    end

    private

    attr_reader :records
  end

  it 'looks up the project by id' do
    repository = FindProjectRepository.new
    action = described_class.new(project_repository: repository)

    expect(repository).to receive(:find).with('123').and_return(Project.new(name: 'Status'))

    action.perform(id: '123')
  end

  it 'returns a successful result when the project exists' do
    repository = FindProjectRepository.new
    repository.add(id: '123', name: 'Status')
    action = described_class.new(project_repository: repository)

    result = action.perform(id: '123')

    expect(result.success?).to be(true)
  end

  it 'returns the found project as the result value' do
    repository = FindProjectRepository.new
    repository.add(id: '123', name: 'Status', description: 'Internal', point_of_contact: 'Alex')
    action = described_class.new(project_repository: repository)

    result = action.perform(id: '123')

    expect(result.value).to be_a(Project)
  end

  it 'returns no errors when the project exists' do
    repository = FindProjectRepository.new
    repository.add(id: '123', name: 'Status')
    action = described_class.new(project_repository: repository)

    result = action.perform(id: '123')

    expect(result.errors).to eq([])
  end

  it 'returns a failure result when the project does not exist' do
    repository = FindProjectRepository.new
    action = described_class.new(project_repository: repository)

    result = action.perform(id: 'missing')

    expect(result.success?).to be(false)
  end

  it 'returns errors when the project does not exist' do
    repository = FindProjectRepository.new
    action = described_class.new(project_repository: repository)

    result = action.perform(id: 'missing')

    expect(result.errors).to eq(['project not found'])
  end
end
