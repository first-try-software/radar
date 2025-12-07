require 'spec_helper'
require 'domain/projects/project'

RSpec.describe Project do
  it 'returns its name' do
    project = described_class.new(name: 'Status')

    expect(project.name).to eq('Status')
  end

  it 'returns its description' do
    project = described_class.new(name: 'Status', description: 'Internal status dashboard')

    expect(project.description).to eq('Internal status dashboard')
  end

  it 'defaults description to an empty string when omitted' do
    project = described_class.new(name: 'Status')

    expect(project.description).to eq('')
  end

  it 'returns its point of contact' do
    project = described_class.new(name: 'Status', point_of_contact: 'Alex')

    expect(project.point_of_contact).to eq('Alex')
  end

  it 'defaults point_of_contact to an empty string when omitted' do
    project = described_class.new(name: 'Status')

    expect(project.point_of_contact).to eq('')
  end

  it 'is valid when it has a name' do
    project = described_class.new(name: 'Status')

    expect(project.valid?).to be(true)
  end

  it 'is invalid when its name is blank' do
    project = described_class.new(name: '')

    expect(project.valid?).to be(false)
  end

  it 'records whether it has been archived' do
    project = described_class.new(name: 'Status', archived: true)

    expect(project).to be_archived
  end

  it 'defaults archived to false when omitted' do
    project = described_class.new(name: 'Status')

    expect(project).not_to be_archived
  end

  it 'lazy loads children via the loader' do
    loader = ->(_project) { [described_class.new(name: 'Child')] }
    project = described_class.new(name: 'Parent', children_loader: loader)

    expect(project.children.map(&:name)).to eq(['Child'])
  end

  it 'lazy loads parent via the loader' do
    parent = described_class.new(name: 'Parent')
    loader = ->(_project) { parent }
    project = described_class.new(name: 'Child', parent_loader: loader)

    expect(project.parent).to eq(parent)
  end

  it 'returns nil parent when no loader provided' do
    project = described_class.new(name: 'Child')

    expect(project.parent).to be_nil
  end

  it 'defaults current_state to :new' do
    project = described_class.new(name: 'Status')

    expect(project.current_state).to eq(:new)
  end

  it 'is invalid when initialized with an invalid state' do
    project = described_class.new(name: 'Status', current_state: :invalid)

    expect(project.valid?).to be(false)
    expect(project.errors).to include('state must be valid')
  end

  it 'returns a new project when updating state' do
    project = described_class.new(name: 'Status')

    updated = project.with_state(state: :todo)

    expect(updated.current_state).to eq(:todo)
    expect(updated).not_to equal(project)
  end

  describe 'health' do
    it 'returns :not_available when state is :new' do
      project = described_class.new(name: 'Status')

      expect(project.health).to eq(:not_available)
    end

    it 'returns :not_available when state is :blocked and no updates exist' do
      loader = ->(_project) { [] }
      project = described_class.new(
        name: 'Status',
        current_state: :blocked,
        health_updates_loader: loader,
        weekly_health_updates_loader: loader
      )

      expect(project.health).to eq(:not_available)
    end

    it 'returns the latest health when state is :in_progress' do
      updates = [
        double('HealthUpdate', date: Date.new(2025, 1, 1), health: :on_track),
        double('HealthUpdate', date: Date.new(2025, 1, 8), health: :at_risk)
      ]
      loader = ->(_project) { updates }
      project = described_class.new(
        name: 'Status',
        current_state: :in_progress,
        health_updates_loader: loader,
        weekly_health_updates_loader: loader
      )

      expect(project.health).to eq(:at_risk)
    end

    it 'rolls up health from working subordinate projects' do
      children = [
        double('Project', current_state: :in_progress, health: :on_track),
        double('Project', current_state: :blocked, health: :off_track)
      ]
      health_updates_loader = ->(_project) { [] }
      project = described_class.new(
        name: 'Status',
        current_state: :in_progress,
        children_loader: ->(_project) { children },
        health_updates_loader: health_updates_loader
      )

      expect(project.health).to eq(:at_risk)
    end

    it 'ignores non-working subordinates when rolling up health' do
      children = [
        double('Project', current_state: :done, health: :off_track),
        double('Project', current_state: :todo, health: :on_track)
      ]
      project = described_class.new(
        name: 'Status',
        current_state: :in_progress,
        children_loader: ->(_project) { children },
        health_updates_loader: ->(_project) { [] }
      )

      expect(project.health).to eq(:not_available)
    end

    it 'ignores :not_available subordinate health values' do
      children = [
        double('Project', current_state: :in_progress, health: :not_available),
        double('Project', current_state: :blocked, health: :on_track)
      ]
      health_updates_loader = ->(_project) { [] }
      project = described_class.new(
        name: 'Status',
        current_state: :in_progress,
        children_loader: ->(_project) { children },
        health_updates_loader: health_updates_loader
      )

      expect(project.health).to eq(:on_track)
    end
  end

  describe 'health_trend' do
    it 'returns empty trend when state is :todo' do
      project = described_class.new(name: 'Status')

      expect(project.health_trend).to eq([])
    end

    it 'returns empty trend when no weekly updates exist' do
      loader = ->(_project) { [] }
      project = described_class.new(
        name: 'Status',
        current_state: :in_progress,
        health_updates_loader: loader,
        weekly_health_updates_loader: loader
      )

      expect(project.health_trend).to eq([])
    end

    it 'returns the last six weekly updates when present' do
      updates = (1..10).map do |week|
        double('HealthUpdate', date: Date.new(2025, 1, week), health: :on_track)
      end
      loader = ->(_project) { updates }
      project = described_class.new(
        name: 'Status',
        current_state: :in_progress,
        health_updates_loader: loader,
        weekly_health_updates_loader: loader
      )

      expect(project.health_trend).to eq(updates.last(6))
    end
  end
end
