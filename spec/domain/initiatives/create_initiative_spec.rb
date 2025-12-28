require 'spec_helper'
require 'domain/initiatives/create_initiative'
require_relative '../../support/domain/initiative_builder'
require_relative '../../support/persistence/fake_initiative_repository'

RSpec.describe CreateInitiative do
  include InitiativeBuilder

  it 'stores the created initiative in the repository' do
    repository = FakeInitiativeRepository.new
    action = described_class.new(initiative_repository: repository)

    action.perform(
      name: 'Modernize Infra',
      description: 'Refresh platform services',
      point_of_contact: 'Jordan'
    )

    stored_initiative = repository.find('Modernize Infra')
    expect(stored_initiative.name).to eq('Modernize Infra')
    expect(stored_initiative.point_of_contact).to eq('Jordan')
  end

  it 'returns a successful result' do
    repository = FakeInitiativeRepository.new
    action = described_class.new(initiative_repository: repository)

    result = action.perform(name: 'Modernize Infra')

    expect(result.success?).to be(true)
  end

  it 'returns the stored initiative as the result value' do
    repository = FakeInitiativeRepository.new
    action = described_class.new(initiative_repository: repository)

    result = action.perform(name: 'Modernize Infra')

    expect(result.value).to be_a(Initiative)
  end

  it 'returns no errors on success' do
    repository = FakeInitiativeRepository.new
    action = described_class.new(initiative_repository: repository)

    result = action.perform(name: 'Modernize Infra')

    expect(result.errors).to eq([])
  end

  it 'returns a failure result when the initiative is invalid' do
    repository = FakeInitiativeRepository.new
    action = described_class.new(initiative_repository: repository)

    result = action.perform(name: '')

    expect(result.success?).to be(false)
  end

  it 'does not store an initiative when it is invalid' do
    repository = FakeInitiativeRepository.new
    action = described_class.new(initiative_repository: repository)

    action.perform(name: '')

    expect(repository.exists_with_name?('')).to be(false)
  end

  it 'returns validation errors when the initiative is invalid' do
    repository = FakeInitiativeRepository.new
    action = described_class.new(initiative_repository: repository)

    result = action.perform(name: '')

    expect(result.errors).to eq(['name must be present'])
  end

  it 'fails when the name conflicts with an existing initiative' do
    repository = FakeInitiativeRepository.new
    repository.save(build_initiative(name: 'Modernize Infra'))
    action = described_class.new(initiative_repository: repository)

    result = action.perform(name: 'Modernize Infra')

    expect(result.success?).to be(false)
    expect(result.errors).to eq(['initiative name must be unique'])
  end
end
