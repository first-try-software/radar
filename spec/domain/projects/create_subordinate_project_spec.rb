require 'spec_helper'
require_relative '../../../domain/projects/create_subordinate_project'
require_relative '../../../domain/projects/project'

RSpec.describe CreateSubordinateProject do
  class CreateSubordinateProjectRepository
    attr_reader :records, :relationships

    def initialize(projects: {})
      @projects = projects
      @records = []
      @relationships = []
    end

    def find(id)
      projects[id]
    end

    def save(project)
      records << project
    end

    def link_subordinate(parent_id:, child:, order:)
      relationships << { parent_id:, child:, order: }
    end

    def exists_with_name?(name)
      projects.values.any? { |project| project.name == name } ||
        records.any? { |project| project.name == name }
    end

    def next_subordinate_order(parent_id:)
      max = relationships.select { |rel| rel[:parent_id] == parent_id }.map { |rel| rel[:order] }.max
      max ? max + 1 : 0
    end

    private

    attr_reader :projects
  end

  it 'returns an error when the parent project cannot be found' do
    repository = CreateSubordinateProjectRepository.new
    action = described_class.new(project_repository: repository)

    result = action.perform(parent_id: '123', name: 'Child')

    expect(result.success?).to be(false)
    expect(result.errors).to eq(['project not found'])
  end

  it 'returns an error when the subordinate project is invalid' do
    parent = Project.new(name: 'Parent')
    repository = CreateSubordinateProjectRepository.new(projects: { '123' => parent })
    action = described_class.new(project_repository: repository)

    result = action.perform(parent_id: '123', name: '')

    expect(result.success?).to be(false)
    expect(result.errors).to eq(['name must be present'])
  end

  it 'returns an error when the subordinate project name already exists' do
    parent = Project.new(name: 'Parent')
    repository = CreateSubordinateProjectRepository.new(
      projects: { '123' => parent, '456' => Project.new(name: 'Child') }
    )
    action = described_class.new(project_repository: repository)

    result = action.perform(parent_id: '123', name: 'Child')

    expect(result.success?).to be(false)
    expect(result.errors).to eq(['project name must be unique'])
  end

  it 'adds the subordinate project to the parent and repository' do
    parent = Project.new(name: 'Parent')
    repository = CreateSubordinateProjectRepository.new(projects: { '123' => parent })
    action = described_class.new(project_repository: repository)

    result = action.perform(
      parent_id: '123',
      name: 'New Child',
      description: 'Sub project',
      point_of_contact: 'Alex'
    )

    expect(result.success?).to be(true)
    subordinate = repository.records.first
    expect(subordinate.name).to eq('New Child')

    relationship = repository.relationships.first
    expect(relationship[:parent_id]).to eq('123')
    expect(relationship[:child].name).to eq('New Child')
    expect(relationship[:order]).to eq(0)
  end

  it 'rejects duplicate subordinate names that were just persisted' do
    parent = Project.new(name: 'Parent')
    repository = CreateSubordinateProjectRepository.new(projects: { '123' => parent })
    action = described_class.new(project_repository: repository)

    action.perform(parent_id: '123', name: 'New Child')
    second_attempt = action.perform(parent_id: '123', name: 'New Child')

    expect(second_attempt.success?).to be(false)
    expect(second_attempt.errors).to eq(['project name must be unique'])
  end
end
