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

  it 'returns its current_state' do
    initiative = described_class.new(name: 'Modernize Infra', current_state: :in_progress)

    expect(initiative.current_state).to eq(:in_progress)
  end

  it 'defaults current_state to :new' do
    initiative = described_class.new(name: 'Modernize Infra')

    expect(initiative.current_state).to eq(:new)
  end

  it 'converts string state to symbol' do
    initiative = described_class.new(name: 'Modernize Infra', current_state: 'in_progress')

    expect(initiative.current_state).to eq(:in_progress)
  end

  it 'is invalid when state is not allowed' do
    initiative = described_class.new(name: 'Modernize Infra', current_state: :invalid_state)

    expect(initiative.valid?).to be(false)
    expect(initiative.errors).to include('state must be valid')
  end

  it 'returns cascades_state? true for cascading states' do
    initiative = described_class.new(name: 'Modernize Infra')

    expect(initiative.cascades_state?(:on_hold)).to be(true)
    expect(initiative.cascades_state?(:done)).to be(true)
    expect(initiative.cascades_state?(:todo)).to be(true)
  end

  it 'returns cascades_state? false for non-cascading states' do
    initiative = described_class.new(name: 'Modernize Infra')

    expect(initiative.cascades_state?(:in_progress)).to be(false)
    expect(initiative.cascades_state?(:blocked)).to be(false)
    expect(initiative.cascades_state?(:new)).to be(false)
  end

  it 'creates a copy with new state using with_state' do
    initiative = described_class.new(name: 'Modernize Infra', current_state: :new)

    updated = initiative.with_state(:in_progress)

    expect(updated.current_state).to eq(:in_progress)
    expect(updated.name).to eq('Modernize Infra')
    expect(initiative.current_state).to eq(:new)
  end

  describe '#derived_state' do
    it 'returns current_state when no related projects' do
      initiative = described_class.new(name: 'Modernize Infra', current_state: :todo)

      expect(initiative.derived_state).to eq(:todo)
    end

    it 'returns highest priority state from related projects' do
      related_projects = [
        double('Project', current_state: :todo),
        double('Project', current_state: :blocked),
        double('Project', current_state: :in_progress)
      ]
      initiative = described_class.new(
        name: 'Modernize Infra',
        current_state: :todo,
        related_projects_loader: ->(_initiative) { related_projects }
      )

      expect(initiative.derived_state).to eq(:blocked)
    end
  end

  describe '#projects_in_state' do
    it 'returns projects matching the given state' do
      blocked_project = double('Project', current_state: :blocked)
      active_project = double('Project', current_state: :in_progress)
      related_projects = [blocked_project, active_project]
      initiative = described_class.new(
        name: 'Modernize Infra',
        related_projects_loader: ->(_initiative) { related_projects }
      )

      result = initiative.projects_in_state(:blocked)

      expect(result).to eq([blocked_project])
    end
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

  it 'returns no validation errors when valid' do
    initiative = described_class.new(name: 'Modernize Infra')

    expect(initiative.errors).to eq([])
  end

  it 'returns empty related projects when no loader provided' do
    initiative = described_class.new(name: 'Modernize Infra')

    expect(initiative.related_projects).to eq([])
  end

  it 'lazy loads related projects via the loader' do
    loader = ->(_initiative) { [double('Project')] }
    initiative = described_class.new(name: 'Modernize Infra', related_projects_loader: loader)

    expect(initiative.related_projects.length).to eq(1)
  end

  describe '#health' do
    it 'returns a rollup of related projects in working states' do
      related_projects = [
        double('Project', current_state: :in_progress, health: :off_track, leaf?: true, id: 1, name: 'P1'),
        double('Project', current_state: :blocked, health: :off_track, leaf?: true, id: 2, name: 'P2'),
        double('Project', current_state: :todo, health: :on_track, leaf?: true, id: 3, name: 'P3')
      ]
      initiative = described_class.new(
        name: 'Modernize Infra',
        related_projects_loader: ->(_initiative) { related_projects }
      )

      expect(initiative.health).to eq(:off_track)
    end

    it 'returns :not_available when no related projects are in a working state' do
      related_projects = [
        double('Project', current_state: :todo, health: :on_track, leaf?: true, id: 1, name: 'P1'),
        double('Project', current_state: :done, health: :off_track, leaf?: true, id: 2, name: 'P2')
      ]
      initiative = described_class.new(
        name: 'Modernize Infra',
        related_projects_loader: ->(_initiative) { related_projects }
      )

      expect(initiative.health).to eq(:not_available)
    end

    it 'uses leaf descendants for parent projects' do
      leaf1 = double('Leaf1', current_state: :in_progress, health: :on_track, leaf?: true, id: 1, name: 'Leaf1')
      leaf2 = double('Leaf2', current_state: :in_progress, health: :on_track, leaf?: true, id: 2, name: 'Leaf2')
      parent = double('Parent', leaf?: false, leaf_descendants: [leaf1, leaf2])

      initiative = described_class.new(
        name: 'Modernize Infra',
        related_projects_loader: ->(_initiative) { [parent] }
      )

      expect(initiative.health).to eq(:on_track)
    end
  end
end
