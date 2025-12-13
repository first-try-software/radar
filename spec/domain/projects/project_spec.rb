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

    it 'excludes future-dated health updates from current health' do
      updates = [
        double('HealthUpdate', date: Date.today - 7, health: :on_track),
        double('HealthUpdate', date: Date.today + 7, health: :off_track)
      ]
      project = described_class.new(
        name: 'Status',
        current_state: :in_progress,
        health_updates_loader: ->(_) { updates },
        weekly_health_updates_loader: ->(_) { [] }
      )

      expect(project.health).to eq(:on_track)
    end
  end

  describe 'health_trend' do
    it 'returns empty trend when state is :todo' do
      project = described_class.new(name: 'Status')

      expect(project.health_trend).to eq([])
    end

    it 'returns only current health when no weekly updates exist for leaf project' do
      loader = ->(_project) { [] }
      project = described_class.new(
        name: 'Status',
        current_state: :in_progress,
        health_updates_loader: loader,
        weekly_health_updates_loader: loader
      )

      current_date = Date.respond_to?(:current) ? Date.current : Date.today
      trend = project.health_trend

      expect(trend.length).to eq(1)
      expect(trend[0].date).to eq(current_date)
      expect(trend[0].health).to eq(:not_available)
    end

    it 'returns weekly updates plus current health for leaf project' do
      current_date = Date.respond_to?(:current) ? Date.current : Date.today
      weekly_updates = [
        double('HealthUpdate', date: Date.new(2025, 1, 5), health: :on_track),
        double('HealthUpdate', date: Date.new(2025, 1, 12), health: :at_risk)
      ]
      health_updates = [
        double('HealthUpdate', date: Date.new(2025, 1, 12), health: :at_risk, description: 'Some update')
      ]
      project = described_class.new(
        name: 'Status',
        current_state: :in_progress,
        health_updates_loader: ->(_) { health_updates },
        weekly_health_updates_loader: ->(_) { weekly_updates }
      )

      trend = project.health_trend

      expect(trend.length).to eq(3)
      expect(trend[0].date).to eq(Date.new(2025, 1, 5))
      expect(trend[1].date).to eq(Date.new(2025, 1, 12))
      expect(trend[2].date).to eq(current_date)
      expect(trend[2].health).to eq(:at_risk)
      expect(trend[2].description).to eq('Some update')
    end

    it 'returns weekly rollups of children health plus current health for parent project' do
      monday1 = Date.new(2025, 1, 6)
      monday2 = Date.new(2025, 1, 13)
      child1_trend = [
        double('HealthUpdate', date: monday1, health: :on_track),
        double('HealthUpdate', date: monday2, health: :on_track)
      ]
      child2_trend = [
        double('HealthUpdate', date: monday1, health: :off_track),
        double('HealthUpdate', date: monday2, health: :off_track)
      ]
      child1 = double('Project', health_trend: child1_trend, current_state: :in_progress, health: :on_track)
      child2 = double('Project', health_trend: child2_trend, current_state: :in_progress, health: :off_track)

      project = described_class.new(
        name: 'Parent',
        current_state: :in_progress,
        children_loader: ->(_) { [child1, child2] },
        health_updates_loader: ->(_) { [] },
        weekly_health_updates_loader: ->(_) { [] }
      )

      trend = project.health_trend

      expect(trend.length).to eq(3)
      expect(trend[0].date).to eq(monday1)
      expect(trend[0].health).to eq(:at_risk)
      expect(trend[1].date).to eq(monday2)
      expect(trend[1].health).to eq(:at_risk)
      current_date = Date.respond_to?(:current) ? Date.current : Date.today
      expect(trend[2].date).to eq(current_date)
      expect(trend[2].health).to eq(:at_risk)
    end

    it 'includes all 6 historical weeks plus current for parent project' do
      mondays = (1..6).map { |i| Date.new(2025, 1, 6) + (i * 7) }
      child_trend = mondays.map { |m| double('HealthUpdate', date: m, health: :on_track) }
      child = double('Project', health_trend: child_trend, current_state: :in_progress, health: :on_track)

      project = described_class.new(
        name: 'Parent',
        current_state: :in_progress,
        children_loader: ->(_) { [child] },
        health_updates_loader: ->(_) { [] },
        weekly_health_updates_loader: ->(_) { [] }
      )

      trend = project.health_trend

      current_date = Date.respond_to?(:current) ? Date.current : Date.today
      expect(trend.length).to eq(7)
      expect(trend[0..5].map(&:date)).to eq(mondays)
      expect(trend[6].date).to eq(current_date)
      expect(trend[6].health).to eq(:on_track)
    end

    it 'returns only current health for parent when children have no trends' do
      child = double('Project', health_trend: [], current_state: :in_progress, health: :on_track)
      project = described_class.new(
        name: 'Parent',
        current_state: :in_progress,
        children_loader: ->(_) { [child] },
        health_updates_loader: ->(_) { [] },
        weekly_health_updates_loader: ->(_) { [] }
      )

      trend = project.health_trend

      current_date = Date.respond_to?(:current) ? Date.current : Date.today
      expect(trend.length).to eq(1)
      expect(trend[0].health).to eq(:on_track)
      expect(trend[0].date).to eq(current_date)
    end

    it 'excludes future-dated weekly updates from leaf project trend' do
      current_date = Date.respond_to?(:current) ? Date.current : Date.today
      updates = [
        double('HealthUpdate', date: current_date - 7, health: :on_track),
        double('HealthUpdate', date: current_date + 7, health: :off_track)
      ]
      project = described_class.new(
        name: 'Status',
        current_state: :in_progress,
        health_updates_loader: ->(_) { [] },
        weekly_health_updates_loader: ->(_) { updates }
      )

      trend = project.health_trend

      expect(trend.length).to eq(2)
      expect(trend[0].health).to eq(:on_track)
      expect(trend[1].date).to eq(current_date)
      expect(trend[1].health).to eq(:not_available)
    end

    it 'excludes future-dated weeks from parent project trend' do
      current_date = Date.respond_to?(:current) ? Date.current : Date.today
      past_monday = current_date - 7
      future_monday = current_date + 7
      child_trend = [
        double('HealthUpdate', date: past_monday, health: :on_track),
        double('HealthUpdate', date: future_monday, health: :off_track)
      ]
      child = double('Project', health_trend: child_trend, current_state: :in_progress, health: :on_track)

      project = described_class.new(
        name: 'Parent',
        current_state: :in_progress,
        children_loader: ->(_) { [child] },
        health_updates_loader: ->(_) { [] },
        weekly_health_updates_loader: ->(_) { [] }
      )

      trend = project.health_trend

      expect(trend.length).to eq(2)
      expect(trend[0].date).to eq(past_monday)
      expect(trend[1].date).to eq(current_date)
    end
  end

  describe 'children_health_for_tooltip' do
    it 'returns nil when project has no children' do
      project = described_class.new(
        name: 'Status',
        current_state: :in_progress,
        children_loader: ->(_) { [] }
      )

      expect(project.children_health_for_tooltip).to be_nil
    end

    it 'returns children with name and health when project has children' do
      child1 = described_class.new(name: 'Child 1', current_state: :in_progress)
      child2 = described_class.new(name: 'Child 2', current_state: :blocked)
      allow(child1).to receive(:health).and_return(:on_track)
      allow(child2).to receive(:health).and_return(:off_track)

      project = described_class.new(
        name: 'Parent',
        current_state: :in_progress,
        children_loader: ->(_) { [child1, child2] }
      )

      result = project.children_health_for_tooltip

      expect(result.length).to eq(2)
      expect(result[0].name).to eq('Child 1')
      expect(result[0].health).to eq(:on_track)
      expect(result[1].name).to eq('Child 2')
      expect(result[1].health).to eq(:off_track)
    end

    it 'includes all children regardless of state' do
      child1 = described_class.new(name: 'Working', current_state: :in_progress)
      child2 = described_class.new(name: 'Done', current_state: :done)
      allow(child1).to receive(:health).and_return(:on_track)
      allow(child2).to receive(:health).and_return(:not_available)

      project = described_class.new(
        name: 'Parent',
        current_state: :in_progress,
        children_loader: ->(_) { [child1, child2] }
      )

      result = project.children_health_for_tooltip

      expect(result.length).to eq(2)
      expect(result.map(&:name)).to eq(['Working', 'Done'])
    end
  end
end
