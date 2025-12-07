require 'spec_helper'

require_relative '../../persistence/fake_initiative_repository'

RSpec.describe FakeInitiativeRepository do
  it 'finds initiatives by id' do
    repository = FakeInitiativeRepository.new
    initiative = Struct.new(:name).new('Modernize Infra')
    repository.update(id: 'init-123', initiative: initiative)

    result = repository.find('init-123')

    expect(result).to eq(initiative)
  end

  it 'updates initiatives by id' do
    repository = FakeInitiativeRepository.new
    initiative = Struct.new(:name).new('Modernize Infra')

    repository.update(id: 'init-123', initiative: initiative)

    expect(repository.find('init-123')).to eq(initiative)
  end

  it 'saves new initiatives without specifying an id' do
    repository = FakeInitiativeRepository.new
    initiative = Struct.new(:name).new('Modernize Infra')

    repository.save(initiative)

    expect(repository.exists_with_name?('Modernize Infra')).to be(true)
  end

  it 'checks for name uniqueness' do
    repository = FakeInitiativeRepository.new
    initiative = Struct.new(:name).new('Modernize Infra')
    repository.update(id: 'init-123', initiative: initiative)

    expect(repository.exists_with_name?('Modernize Infra')).to be(true)
    expect(repository.exists_with_name?('Other')).to be(false)
  end

  it 'tracks related project relationships with incremental order' do
    repository = FakeInitiativeRepository.new
    project = Struct.new(:name).new('Status')

    repository.link_related_project(initiative_id: 'init-123', project: project, order: 0)

    expect(repository.next_related_project_order(initiative_id: 'init-123')).to eq(1)
  end
end
