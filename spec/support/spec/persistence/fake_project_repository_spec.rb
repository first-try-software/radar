require 'spec_helper'

require_relative '../../persistence/fake_project_repository'

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

  it 'scopes subordinate ordering per parent' do
    repository = FakeProjectRepository.new
    first_child = Struct.new(:name).new('FirstChild')
    second_child = Struct.new(:name).new('SecondChild')

    repository.link_subordinate(parent_id: 'parent-1', child: first_child, order: 0)
    repository.link_subordinate(parent_id: 'parent-2', child: second_child, order: 0)

    expect(repository.next_subordinate_order(parent_id: 'parent-1')).to eq(1)
    expect(repository.next_subordinate_order(parent_id: 'parent-2')).to eq(1)
  end

  it 'enforces a single parent per child' do
    repository = FakeProjectRepository.new
    child = Struct.new(:name).new('Child')
    repository.link_subordinate(parent_id: 'parent-1', child: child, order: 0)

    expect {
      repository.link_subordinate(parent_id: 'parent-2', child: child, order: 0)
    }.to raise_error(/already has a parent/)
  end

  it 'rejects linking the same child twice to the same parent' do
    repository = FakeProjectRepository.new
    child = Struct.new(:name).new('Child')
    repository.link_subordinate(parent_id: 'parent-1', child: child, order: 0)

    expect {
      repository.link_subordinate(parent_id: 'parent-1', child: child, order: 1)
    }.to raise_error(/already has a parent/)
  end
end
