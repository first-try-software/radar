require 'spec_helper'
require 'domain/initiatives/find_initiative'
require_relative '../../support/domain/initiative_builder'
require_relative '../../support/persistence/fake_initiative_repository'

RSpec.describe FindInitiative do
  include InitiativeBuilder

  it 'looks up the initiative by id' do
    repository = FakeInitiativeRepository.new
    action = described_class.new(initiative_repository: repository)

    expect(repository).to receive(:find).with('init-123').and_return(build_initiative(name: 'Modernize Infra'))

    action.perform(id: 'init-123')
  end

  it 'returns a successful result when the initiative exists' do
    repository = FakeInitiativeRepository.new
    repository.update(id: 'init-123', initiative: build_initiative(name: 'Modernize Infra'))
    action = described_class.new(initiative_repository: repository)

    result = action.perform(id: 'init-123')

    expect(result.success?).to be(true)
  end

  it 'returns the found initiative as the result value' do
    repository = FakeInitiativeRepository.new
    repository.update(id: 'init-123', initiative: build_initiative(name: 'Modernize Infra'))
    action = described_class.new(initiative_repository: repository)

    result = action.perform(id: 'init-123')

    expect(result.value).to be_a(Initiative)
  end

  it 'returns no errors when the initiative exists' do
    repository = FakeInitiativeRepository.new
    repository.update(id: 'init-123', initiative: build_initiative(name: 'Modernize Infra'))
    action = described_class.new(initiative_repository: repository)

    result = action.perform(id: 'init-123')

    expect(result.errors).to eq([])
  end

  it 'returns a failure result when the initiative does not exist' do
    repository = FakeInitiativeRepository.new
    action = described_class.new(initiative_repository: repository)

    result = action.perform(id: 'missing')

    expect(result.success?).to be(false)
  end

  it 'returns errors when the initiative does not exist' do
    repository = FakeInitiativeRepository.new
    action = described_class.new(initiative_repository: repository)

    result = action.perform(id: 'missing')

    expect(result.errors).to eq(['initiative not found'])
  end
end
