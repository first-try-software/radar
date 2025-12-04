require 'spec_helper'
require_relative '../../domain/initiatives/update_initiative'
require_relative '../../domain/initiatives/initiative'

RSpec.describe UpdateInitiative do
  class UpdateInitiativeRepository
    attr_reader :records

    def initialize
      @records = {}
    end

    def seed(id:, initiative:)
      records[id] = initiative
    end

    def find(id)
      records[id]
    end

    def save(id:, initiative:)
      records[id] = initiative
    end
  end

  it 'looks up the existing initiative by id' do
    repository = UpdateInitiativeRepository.new
    action = described_class.new(initiative_repository: repository)

    expect(repository).to receive(:find).with('init-123').and_return(Initiative.new(name: 'Modernize Infra'))

    action.perform(id: 'init-123', name: 'Modernize Infra 2')
  end

  it 'stores the new initiative over the existing record' do
    repository = UpdateInitiativeRepository.new
    repository.seed(id: 'init-123', initiative: Initiative.new(name: 'Modernize Infra'))
    action = described_class.new(initiative_repository: repository)

    action.perform(id: 'init-123', name: 'Modernize Infra 2', description: 'New description', archived: true)

    stored_initiative = repository.records['init-123']
    expect(stored_initiative.name).to eq('Modernize Infra 2')
  end

  it 'returns a successful result when the update succeeds' do
    repository = UpdateInitiativeRepository.new
    repository.seed(id: 'init-123', initiative: Initiative.new(name: 'Modernize Infra'))
    action = described_class.new(initiative_repository: repository)

    result = action.perform(id: 'init-123', name: 'Modernize Infra 2')

    expect(result.success?).to be(true)
  end

  it 'returns the updated initiative as the result value' do
    repository = UpdateInitiativeRepository.new
    repository.seed(id: 'init-123', initiative: Initiative.new(name: 'Modernize Infra'))
    action = described_class.new(initiative_repository: repository)

    result = action.perform(id: 'init-123', name: 'Modernize Infra 2')

    expect(result.value).to be_a(Initiative)
  end

  it 'returns no errors when the update succeeds' do
    repository = UpdateInitiativeRepository.new
    repository.seed(id: 'init-123', initiative: Initiative.new(name: 'Modernize Infra'))
    action = described_class.new(initiative_repository: repository)

    result = action.perform(id: 'init-123', name: 'Modernize Infra 2')

    expect(result.errors).to eq([])
  end

  it 'returns a failure result when the initiative cannot be found' do
    repository = UpdateInitiativeRepository.new
    action = described_class.new(initiative_repository: repository)

    result = action.perform(id: 'missing', name: 'Modernize Infra 2')

    expect(result.success?).to be(false)
  end

  it 'returns errors when the initiative cannot be found' do
    repository = UpdateInitiativeRepository.new
    action = described_class.new(initiative_repository: repository)

    result = action.perform(id: 'missing', name: 'Modernize Infra 2')

    expect(result.errors).to eq(['initiative not found'])
  end

  it 'returns a failure result when the new initiative is invalid' do
    repository = UpdateInitiativeRepository.new
    repository.seed(id: 'init-123', initiative: Initiative.new(name: 'Modernize Infra'))
    action = described_class.new(initiative_repository: repository)

    result = action.perform(id: 'init-123', name: '')

    expect(result.success?).to be(false)
  end

  it 'does not store a new initiative when it is invalid' do
    repository = UpdateInitiativeRepository.new
    repository.seed(id: 'init-123', initiative: Initiative.new(name: 'Modernize Infra'))
    action = described_class.new(initiative_repository: repository)

    action.perform(id: 'init-123', name: '')

    expect(repository.records['init-123'].name).to eq('Modernize Infra')
  end

  it 'returns validation errors when the new initiative is invalid' do
    repository = UpdateInitiativeRepository.new
    repository.seed(id: 'init-123', initiative: Initiative.new(name: 'Modernize Infra'))
    action = described_class.new(initiative_repository: repository)

    result = action.perform(id: 'init-123', name: '')

    expect(result.errors).to eq(['name must be present'])
  end
end
