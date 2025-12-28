require 'spec_helper'
require 'domain/initiatives/update_initiative'
require_relative '../../support/domain/initiative_builder'
require_relative '../../support/persistence/fake_initiative_repository'

RSpec.describe UpdateInitiative do
  include InitiativeBuilder

  it 'looks up the existing initiative by id' do
    repository = FakeInitiativeRepository.new
    action = described_class.new(initiative_repository: repository)

    expect(repository).to receive(:find).with('init-123').and_return(build_initiative(name: 'Modernize Infra'))

    action.perform(id: 'init-123', name: 'Modernize Infra 2')
  end

  it 'stores the new initiative over the existing record' do
    repository = FakeInitiativeRepository.new
    repository.update(id: 'init-123', initiative: build_initiative(name: 'Modernize Infra'))
    action = described_class.new(initiative_repository: repository)

    action.perform(
      id: 'init-123',
      name: 'Modernize Infra 2',
      description: 'New description',
      point_of_contact: 'Jordan',
      archived: true
    )

    stored_initiative = repository.find('init-123')
    expect(stored_initiative.name).to eq('Modernize Infra 2')
    expect(stored_initiative.point_of_contact).to eq('Jordan')
  end

  it 'returns a successful result when the update succeeds' do
    repository = FakeInitiativeRepository.new
    repository.update(id: 'init-123', initiative: build_initiative(name: 'Modernize Infra'))
    action = described_class.new(initiative_repository: repository)

    result = action.perform(id: 'init-123', name: 'Modernize Infra 2', point_of_contact: 'Jordan')

    expect(result.success?).to be(true)
  end

  it 'returns the updated initiative as the result value' do
    repository = FakeInitiativeRepository.new
    repository.update(id: 'init-123', initiative: build_initiative(name: 'Modernize Infra'))
    action = described_class.new(initiative_repository: repository)

    result = action.perform(id: 'init-123', name: 'Modernize Infra 2', point_of_contact: 'Jordan')

    expect(result.value).to be_a(Initiative)
  end

  it 'returns no errors when the update succeeds' do
    repository = FakeInitiativeRepository.new
    repository.update(id: 'init-123', initiative: build_initiative(name: 'Modernize Infra'))
    action = described_class.new(initiative_repository: repository)

    result = action.perform(id: 'init-123', name: 'Modernize Infra 2', point_of_contact: 'Jordan')

    expect(result.errors).to eq([])
  end

  it 'returns a failure result when the initiative cannot be found' do
    repository = FakeInitiativeRepository.new
    action = described_class.new(initiative_repository: repository)

    result = action.perform(id: 'missing', name: 'Modernize Infra 2', point_of_contact: 'Jordan')

    expect(result.success?).to be(false)
  end

  it 'returns errors when the initiative cannot be found' do
    repository = FakeInitiativeRepository.new
    action = described_class.new(initiative_repository: repository)

    result = action.perform(id: 'missing', name: 'Modernize Infra 2', point_of_contact: 'Jordan')

    expect(result.errors).to eq(['initiative not found'])
  end

  it 'returns a failure result when the new initiative is invalid' do
    repository = FakeInitiativeRepository.new
    repository.update(id: 'init-123', initiative: build_initiative(name: 'Modernize Infra'))
    action = described_class.new(initiative_repository: repository)

    result = action.perform(id: 'init-123', name: '', point_of_contact: 'Jordan')

    expect(result.success?).to be(false)
  end

  it 'does not store a new initiative when it is invalid' do
    repository = FakeInitiativeRepository.new
    repository.update(id: 'init-123', initiative: build_initiative(name: 'Modernize Infra'))
    action = described_class.new(initiative_repository: repository)

    action.perform(id: 'init-123', name: '', point_of_contact: 'Jordan')

    expect(repository.find('init-123').name).to eq('Modernize Infra')
  end

  it 'returns validation errors when the new initiative is invalid' do
    repository = FakeInitiativeRepository.new
    repository.update(id: 'init-123', initiative: build_initiative(name: 'Modernize Infra'))
    action = described_class.new(initiative_repository: repository)

    result = action.perform(id: 'init-123', name: '', point_of_contact: 'Jordan')

    expect(result.errors).to eq(['name must be present'])
  end

  it 'fails when the new name conflicts with another initiative' do
    repository = FakeInitiativeRepository.new
    repository.update(id: 'init-123', initiative: build_initiative(name: 'Modernize Infra'))
    repository.update(id: 'init-456', initiative: build_initiative(name: 'Platform Refresh'))
    action = described_class.new(initiative_repository: repository)

    result = action.perform(id: 'init-123', name: 'Platform Refresh')

    expect(result.success?).to be(false)
    expect(result.errors).to eq(['initiative name must be unique'])
  end

  it 'preserves existing name when name is not provided' do
    repository = FakeInitiativeRepository.new
    repository.update(id: 'init-123', initiative: build_initiative(name: 'Modernize Infra', description: 'Old desc'))
    action = described_class.new(initiative_repository: repository)

    action.perform(id: 'init-123', description: 'New desc')

    expect(repository.find('init-123').name).to eq('Modernize Infra')
    expect(repository.find('init-123').description).to eq('New desc')
  end

  it 'preserves existing description when description is not provided' do
    repository = FakeInitiativeRepository.new
    repository.update(id: 'init-123', initiative: build_initiative(name: 'Modernize Infra', description: 'Old desc'))
    action = described_class.new(initiative_repository: repository)

    action.perform(id: 'init-123', name: 'New Name')

    expect(repository.find('init-123').description).to eq('Old desc')
  end

  it 'preserves existing point_of_contact when not provided' do
    repository = FakeInitiativeRepository.new
    repository.update(id: 'init-123', initiative: build_initiative(name: 'Modernize Infra', point_of_contact: 'Jordan'))
    action = described_class.new(initiative_repository: repository)

    action.perform(id: 'init-123', name: 'New Name')

    expect(repository.find('init-123').point_of_contact).to eq('Jordan')
  end

  it 'preserves existing archived status when not provided' do
    repository = FakeInitiativeRepository.new
    repository.update(id: 'init-123', initiative: build_initiative(name: 'Modernize Infra', archived: true))
    action = described_class.new(initiative_repository: repository)

    action.perform(id: 'init-123', name: 'New Name')

    expect(repository.find('init-123').archived?).to be(true)
  end

  it 'allows setting description to empty string' do
    repository = FakeInitiativeRepository.new
    repository.update(id: 'init-123', initiative: build_initiative(name: 'Modernize Infra', description: 'Old desc'))
    action = described_class.new(initiative_repository: repository)

    action.perform(id: 'init-123', description: '')

    expect(repository.find('init-123').description).to eq('')
  end
end
