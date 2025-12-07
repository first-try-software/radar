require 'spec_helper'
require 'domain/initiatives/initiative'

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

  it 'lazy loads related projects via the loader' do
    loader = ->(_initiative) { [double('Project')] }
    initiative = described_class.new(name: 'Modernize Infra', related_projects_loader: loader)

    expect(initiative.related_projects.length).to eq(1)
  end

  describe '#health' do
    it 'returns a rollup of related projects in working states' do
      related_projects = [
        double('Project', current_state: :in_progress, health: :off_track),
        double('Project', current_state: :blocked, health: :off_track),
        double('Project', current_state: :todo, health: :on_track)
      ]
      initiative = described_class.new(
        name: 'Modernize Infra',
        related_projects_loader: ->(_initiative) { related_projects }
      )

      expect(initiative.health).to eq(:off_track)
    end

    it 'returns :not_available when no related projects are in a working state' do
      related_projects = [
        double('Project', current_state: :todo, health: :on_track),
        double('Project', current_state: :done, health: :off_track)
      ]
      initiative = described_class.new(
        name: 'Modernize Infra',
        related_projects_loader: ->(_initiative) { related_projects }
      )

      expect(initiative.health).to eq(:not_available)
    end
  end
end
