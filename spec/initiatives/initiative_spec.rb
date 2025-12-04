require 'spec_helper'
require_relative '../../domain/initiatives/initiative'

RSpec.describe Initiative do
  it 'returns its name' do
    initiative = described_class.new(name: 'Modernize Infra')

    expect(initiative.name).to eq('Modernize Infra')
  end

  it 'returns its description' do
    initiative = described_class.new(name: 'Modernize Infra', description: 'Refresh all platform services')

    expect(initiative.description).to eq('Refresh all platform services')
  end

  it 'defaults description to an empty string' do
    initiative = described_class.new(name: 'Modernize Infra')

    expect(initiative.description).to eq('')
  end

  it 'returns its point of contact' do
    initiative = described_class.new(name: 'Modernize Infra', point_of_contact: 'Jordan')

    expect(initiative.point_of_contact).to eq('Jordan')
  end

  it 'defaults point_of_contact to an empty string' do
    initiative = described_class.new(name: 'Modernize Infra')

    expect(initiative.point_of_contact).to eq('')
  end

  it 'records whether it is archived' do
    initiative = described_class.new(name: 'Modernize Infra', archived: true)

    expect(initiative).to be_archived
  end

  it 'defaults archived to false' do
    initiative = described_class.new(name: 'Modernize Infra')

    expect(initiative).not_to be_archived
  end

  it 'is valid when it has a name' do
    initiative = described_class.new(name: 'Modernize Infra')

    expect(initiative.valid?).to be(true)
  end

  it 'is invalid when its name is blank' do
    initiative = described_class.new(name: '')

    expect(initiative.valid?).to be(false)
  end

  it 'returns validation errors when invalid' do
    initiative = described_class.new(name: '')

    expect(initiative.errors).to eq(['name must be present'])
  end
end
