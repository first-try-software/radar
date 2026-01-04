require 'spec_helper'
require_relative '../../support/domain/initiative_builder'

RSpec.describe Initiative do
  include InitiativeBuilder

  it 'is invalid when state is not allowed' do
    initiative = build_initiative(name: 'Modernize Infra', current_state: :invalid_state)

    expect(initiative.valid?).to be(false)
    expect(initiative.errors).to include('state must be valid')
  end

  it 'returns cascades_state? true for cascading states' do
    initiative = build_initiative(name: 'Modernize Infra')

    expect(initiative.cascades_state?(:on_hold)).to be(true)
    expect(initiative.cascades_state?(:done)).to be(true)
    expect(initiative.cascades_state?(:todo)).to be(true)
  end

  it 'returns cascades_state? false for non-cascading states' do
    initiative = build_initiative(name: 'Modernize Infra')

    expect(initiative.cascades_state?(:in_progress)).to be(false)
    expect(initiative.cascades_state?(:blocked)).to be(false)
    expect(initiative.cascades_state?(:new)).to be(false)
  end

  it 'creates a copy with new state using with_state' do
    initiative = build_initiative(name: 'Modernize Infra', current_state: :new)

    updated = initiative.with_state(:in_progress)

    expect(updated.current_state).to eq(:in_progress)
    expect(updated.name).to eq('Modernize Infra')
    expect(initiative.current_state).to eq(:new)
  end

  it 'preserves id when using with_state' do
    initiative = build_initiative(id: '42', name: 'Modernize Infra', current_state: :new)

    updated = initiative.with_state(:in_progress)

    expect(updated.id).to eq('42')
  end

  describe '#derived_state' do
    it 'returns current_state when no related projects' do
      initiative = build_initiative(name: 'Modernize Infra', current_state: :todo)

      expect(initiative.derived_state).to eq(:todo)
    end

    it 'returns highest priority state from related projects' do
      related_projects = [
        double('Project', current_state: :todo),
        double('Project', current_state: :blocked),
        double('Project', current_state: :in_progress)
      ]
      initiative = build_initiative(
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
      initiative = build_initiative(
        name: 'Modernize Infra',
        related_projects_loader: ->(_initiative) { related_projects }
      )

      result = initiative.projects_in_state(:blocked)

      expect(result).to eq([blocked_project])
    end
  end

  it 'is valid when it has a name' do
    initiative = build_initiative(name: 'Modernize Infra')

    expect(initiative.valid?).to be(true)
  end

  it 'is invalid when its name is blank' do
    initiative = build_initiative(name: '')

    expect(initiative.valid?).to be(false)
  end

  it 'returns validation errors when invalid' do
    initiative = build_initiative(name: '')

    expect(initiative.errors).to eq(['name must be present'])
  end

  it 'returns no validation errors when valid' do
    initiative = build_initiative(name: 'Modernize Infra')

    expect(initiative.errors).to eq([])
  end

  it 'returns empty related projects when no loader provided' do
    initiative = build_initiative(name: 'Modernize Infra')

    expect(initiative.related_projects).to eq([])
  end

  it 'lazy loads related projects via the loader' do
    loader = ->(_initiative) { [double('Project')] }
    initiative = build_initiative(name: 'Modernize Infra', related_projects_loader: loader)

    expect(initiative.related_projects.length).to eq(1)
  end

  describe '#leaf_projects' do
    it 'returns leaf projects directly when related project is a leaf' do
      leaf_project = double('LeafProject', id: 1, leaf?: true)
      initiative = build_initiative(
        name: 'Modernize Infra',
        related_projects_loader: ->(_initiative) { [leaf_project] }
      )

      expect(initiative.leaf_projects).to eq([leaf_project])
    end

    it 'returns leaf descendants when related project is a parent' do
      child_a = double('ChildA', id: 2, name: 'A')
      child_b = double('ChildB', id: 3, name: 'B')
      parent_project = double('ParentProject', id: 1, leaf?: false, leaf_descendants: [child_a, child_b])
      initiative = build_initiative(
        name: 'Modernize Infra',
        related_projects_loader: ->(_initiative) { [parent_project] }
      )

      expect(initiative.leaf_projects).to contain_exactly(child_a, child_b)
    end
  end

  describe '#health' do
    it 'returns a rollup of related projects in active states' do
      related_projects = [
        double('Project', current_state: :in_progress, health: :off_track, archived?: false),
        double('Project', current_state: :blocked, health: :off_track, archived?: false),
        double('Project', current_state: :todo, health: :on_track, archived?: false)
      ]
      initiative = build_initiative(
        name: 'Modernize Infra',
        related_projects_loader: ->(_initiative) { related_projects }
      )

      expect(initiative.health).to eq(:off_track)
    end

    it 'returns :not_available when no related projects are in an active state' do
      related_projects = [
        double('Project', current_state: :todo, health: :on_track, archived?: false),
        double('Project', current_state: :done, health: :off_track, archived?: false)
      ]
      initiative = build_initiative(
        name: 'Modernize Infra',
        related_projects_loader: ->(_initiative) { related_projects }
      )

      expect(initiative.health).to eq(:not_available)
    end

    it 'weights each related project equally regardless of decomposition' do
      # Parent project with many children gets same weight as a leaf project
      leaf_project = double('LeafProject', current_state: :in_progress, health: :off_track, archived?: false)
      parent_project = double('ParentProject', current_state: :in_progress, health: :on_track, archived?: false)

      initiative = build_initiative(
        name: 'Modernize Infra',
        related_projects_loader: ->(_initiative) { [leaf_project, parent_project] }
      )

      # off_track (-1) + on_track (1) = 0 average -> at_risk
      expect(initiative.health).to eq(:at_risk)
    end
  end

  describe '#health_raw_score' do
    it 'returns the raw score from related projects' do
      related_projects = [
        double('Project', current_state: :in_progress, health: :on_track, archived?: false)
      ]
      initiative = build_initiative(
        name: 'Modernize Infra',
        related_projects_loader: ->(_initiative) { related_projects }
      )

      expect(initiative.health_raw_score).to eq(1.0)
    end

    it 'returns nil when no related projects in active state' do
      initiative = build_initiative(name: 'Empty')

      expect(initiative.health_raw_score).to be_nil
    end
  end
end
