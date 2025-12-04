require 'spec_helper'
require_relative '../../../domain/initiatives/create_initiative'
require_relative '../../../domain/initiatives/initiative'

RSpec.describe CreateInitiative do
  class CreateInitiativeRepository
    attr_reader :records

    def initialize
      @records = []
    end

    def save(initiative)
      records << initiative
    end
  end

  it 'stores the created initiative in the repository' do
    repository = CreateInitiativeRepository.new
    action = described_class.new(initiative_repository: repository)

    action.perform(
      name: 'Modernize Infra',
      description: 'Refresh platform services',
      point_of_contact: 'Jordan'
    )

    stored_initiative = repository.records.first
    expect(stored_initiative.name).to eq('Modernize Infra')
    expect(stored_initiative.point_of_contact).to eq('Jordan')
  end

  it 'returns a successful result' do
    repository = CreateInitiativeRepository.new
    action = described_class.new(initiative_repository: repository)

    result = action.perform(name: 'Modernize Infra')

    expect(result.success?).to be(true)
  end

  it 'returns the stored initiative as the result value' do
    repository = CreateInitiativeRepository.new
    action = described_class.new(initiative_repository: repository)

    result = action.perform(name: 'Modernize Infra')

    expect(result.value).to be_a(Initiative)
  end

  it 'returns no errors on success' do
    repository = CreateInitiativeRepository.new
    action = described_class.new(initiative_repository: repository)

    result = action.perform(name: 'Modernize Infra')

    expect(result.errors).to eq([])
  end

  it 'returns a failure result when the initiative is invalid' do
    repository = CreateInitiativeRepository.new
    action = described_class.new(initiative_repository: repository)

    result = action.perform(name: '')

    expect(result.success?).to be(false)
  end

  it 'does not store an initiative when it is invalid' do
    repository = CreateInitiativeRepository.new
    action = described_class.new(initiative_repository: repository)

    action.perform(name: '')

    expect(repository.records).to be_empty
  end

  it 'returns validation errors when the initiative is invalid' do
    repository = CreateInitiativeRepository.new
    action = described_class.new(initiative_repository: repository)

    result = action.perform(name: '')

    expect(result.errors).to eq(['name must be present'])
  end
end
