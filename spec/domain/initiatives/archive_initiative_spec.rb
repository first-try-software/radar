require 'spec_helper'
require 'domain/initiatives/archive_initiative'
require 'domain/initiatives/initiative'
require_relative '../../support/persistence/fake_initiative_repository'

RSpec.describe ArchiveInitiative do
  it 'looks up the initiative by id' do
    repository = FakeInitiativeRepository.new
    action = described_class.new(initiative_repository: repository)

    expect(repository).to receive(:find).with('init-123').and_return(Initiative.new(name: 'Modernize Infra'))

    action.perform(id: 'init-123')
  end

  it 'archives the initiative and saves it' do
    repository = FakeInitiativeRepository.new
    repository.update(
      id: 'init-123',
      initiative: Initiative.new(name: 'Modernize Infra', point_of_contact: 'Jordan')
    )
    action = described_class.new(initiative_repository: repository)

    action.perform(id: 'init-123')

    stored_initiative = repository.find('init-123')
    expect(stored_initiative).to be_archived
    expect(stored_initiative.point_of_contact).to eq('Jordan')
  end

  it 'returns a successful result when the initiative is archived' do
    repository = FakeInitiativeRepository.new
    repository.update(
      id: 'init-123',
      initiative: Initiative.new(name: 'Modernize Infra', point_of_contact: 'Jordan')
    )
    action = described_class.new(initiative_repository: repository)

    result = action.perform(id: 'init-123')

    expect(result.success?).to be(true)
  end

  it 'returns the archived initiative as the result value' do
    repository = FakeInitiativeRepository.new
    repository.update(
      id: 'init-123',
      initiative: Initiative.new(name: 'Modernize Infra', point_of_contact: 'Jordan')
    )
    action = described_class.new(initiative_repository: repository)

    result = action.perform(id: 'init-123')

    expect(result.value).to be_archived
  end

  it 'returns no errors when the initiative is archived' do
    repository = FakeInitiativeRepository.new
    repository.update(id: 'init-123', initiative: Initiative.new(name: 'Modernize Infra'))
    action = described_class.new(initiative_repository: repository)

    result = action.perform(id: 'init-123')

    expect(result.errors).to eq([])
  end

  it 'returns a failure result when the initiative cannot be found' do
    repository = FakeInitiativeRepository.new
    action = described_class.new(initiative_repository: repository)

    result = action.perform(id: 'missing')

    expect(result.success?).to be(false)
  end

  it 'returns errors when the initiative cannot be found' do
    repository = FakeInitiativeRepository.new
    action = described_class.new(initiative_repository: repository)

    result = action.perform(id: 'missing')

    expect(result.errors).to eq(['initiative not found'])
  end
end
