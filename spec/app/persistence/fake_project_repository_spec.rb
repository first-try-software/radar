require 'spec_helper'

require_relative '../../support/persistence/fake_project_repository'

RSpec.describe FakeProjectRepository do
  it 'finds projects by id' do
    repository = FakeProjectRepository.new
    project = Struct.new(:name).new('Status')
    repository.update(id: '123', project: project)

    result = repository.find('123')

    expect(result).to eq(project)
  end

  it 'updates projects by id' do
    repository = FakeProjectRepository.new
    project = Struct.new(:name).new('Status')

    repository.update(id: '123', project: project)

    expect(repository.find('123')).to eq(project)
  end

  it 'saves new projects without specifying an id' do
    repository = FakeProjectRepository.new
    project = Struct.new(:name).new('Status')

    repository.save(project)

    expect(repository.exists_with_name?('Status')).to be(true)
  end

  it 'checks for existing names' do
    repository = FakeProjectRepository.new
    project = Struct.new(:name).new('Status')
    repository.update(id: '123', project: project)

    expect(repository.exists_with_name?('Status')).to be(true)
    expect(repository.exists_with_name?('Other')).to be(false)
  end

  it 'links subordinate projects and tracks order' do
    repository = FakeProjectRepository.new
    child = Struct.new(:name).new('Child')

    repository.link_subordinate(parent_id: '123', child: child, order: 0)

    relationship = repository.subordinate_relationships_for(parent_id: '123').first
    expect(relationship[:child]).to eq(child)
    expect(repository.next_subordinate_order(parent_id: '123')).to eq(1)
  end
end
