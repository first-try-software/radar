require 'spec_helper'
require 'domain/projects/project_health'

RSpec.describe ProjectHealth do
  it 'returns :not_available when no health updates and no children' do
    project_health = described_class.new(
      health_updates_loader: -> { [] },
      weekly_health_updates_loader: -> { [] },
      children_loader: -> { [] }
    )

    expect(project_health.health).to eq(:not_available)
  end

  it 'returns :not_available when health_updates_loader is nil and no children' do
    project_health = described_class.new(
      health_updates_loader: nil,
      weekly_health_updates_loader: nil,
      children_loader: -> { [] }
    )

    expect(project_health.health).to eq(:not_available)
  end

  it 'returns the latest health for leaf with updates' do
    updates = [
      double('HealthUpdate', date: Date.new(2025, 1, 1), health: :on_track),
      double('HealthUpdate', date: Date.new(2025, 1, 8), health: :at_risk)
    ]
    project_health = described_class.new(
      health_updates_loader: -> { updates },
      weekly_health_updates_loader: -> { updates },
      children_loader: -> { [] }
    )

    expect(project_health.health).to eq(:at_risk)
  end

  it 'rolls up health from children' do
    children = [
      double('Child', health: :on_track),
      double('Child', health: :off_track)
    ]
    project_health = described_class.new(
      health_updates_loader: -> { [] },
      weekly_health_updates_loader: -> { [] },
      children_loader: -> { children }
    )

    expect(project_health.health).to eq(:at_risk)
  end

  it 'ignores :not_available child health values' do
    children = [
      double('Child', health: :not_available),
      double('Child', health: :on_track)
    ]
    project_health = described_class.new(
      health_updates_loader: -> { [] },
      weekly_health_updates_loader: -> { [] },
      children_loader: -> { children }
    )

    expect(project_health.health).to eq(:on_track)
  end

  it 'returns :not_available when all children have :not_available health' do
    children = [
      double('Child', health: :not_available),
      double('Child', health: :not_available)
    ]
    project_health = described_class.new(
      health_updates_loader: -> { [] },
      weekly_health_updates_loader: -> { [] },
      children_loader: -> { children }
    )

    expect(project_health.health).to eq(:not_available)
  end

  it 'returns :off_track when all children are off_track' do
    children = [
      double('Child', health: :off_track),
      double('Child', health: :off_track)
    ]
    project_health = described_class.new(
      health_updates_loader: -> { [] },
      weekly_health_updates_loader: -> { [] },
      children_loader: -> { children }
    )

    expect(project_health.health).to eq(:off_track)
  end

  it 'excludes future-dated health updates from current health' do
    updates = [
      double('HealthUpdate', date: Date.today - 7, health: :on_track),
      double('HealthUpdate', date: Date.today + 7, health: :off_track)
    ]
    project_health = described_class.new(
      health_updates_loader: -> { updates },
      weekly_health_updates_loader: -> { [] },
      children_loader: -> { [] }
    )

    expect(project_health.health).to eq(:on_track)
  end

  it 'treats health updates with non-date objects as non-future' do
    non_date_object = Object.new
    updates = [
      double('HealthUpdate', date: non_date_object, health: :at_risk)
    ]
    project_health = described_class.new(
      health_updates_loader: -> { updates },
      weekly_health_updates_loader: -> { [] },
      children_loader: -> { [] }
    )

    expect(project_health.health).to eq(:at_risk)
  end

  it 'uses Date.today when Date does not respond to current' do
    allow(Date).to receive(:respond_to?).and_call_original
    allow(Date).to receive(:respond_to?).with(:current).and_return(false)

    updates = [
      double('HealthUpdate', date: Date.today - 1, health: :on_track)
    ]
    project_health = described_class.new(
      health_updates_loader: -> { updates },
      weekly_health_updates_loader: -> { [] },
      children_loader: -> { [] }
    )

    expect(project_health.health).to eq(:on_track)
  end

  it 'uses Date.current when Date responds to current' do
    allow(Date).to receive(:respond_to?).and_call_original
    allow(Date).to receive(:respond_to?).with(:current).and_return(true)
    allow(Date).to receive(:current).and_return(Date.today)

    updates = [
      double('HealthUpdate', date: Date.today - 1, health: :at_risk)
    ]
    project_health = described_class.new(
      health_updates_loader: -> { updates },
      weekly_health_updates_loader: -> { [] },
      children_loader: -> { [] }
    )

    expect(project_health.health).to eq(:at_risk)
  end

  it 'memoizes children loader result across different method calls' do
    call_count = 0
    children_loader = -> {
      call_count += 1
      [double('Child', name: 'Test', health: :on_track, health_trend: [])]
    }
    project_health = described_class.new(
      health_updates_loader: -> { [] },
      weekly_health_updates_loader: -> { [] },
      children_loader: children_loader
    )

    project_health.health
    project_health.children_health_for_tooltip

    expect(call_count).to eq(1)
  end

  it 'handles nil children_loader gracefully' do
    project_health = described_class.new(
      health_updates_loader: -> { [] },
      weekly_health_updates_loader: -> { [] },
      children_loader: nil
    )

    expect(project_health.health).to eq(:not_available)
  end

  it 'excludes archived children from health rollup' do
    archived_child = double('ArchivedChild', health: :off_track)
    allow(archived_child).to receive(:respond_to?).with(:archived?).and_return(true)
    allow(archived_child).to receive(:archived?).and_return(true)

    active_child = double('ActiveChild', health: :on_track)
    allow(active_child).to receive(:respond_to?).with(:archived?).and_return(true)
    allow(active_child).to receive(:archived?).and_return(false)

    project_health = described_class.new(
      health_updates_loader: -> { [] },
      weekly_health_updates_loader: -> { [] },
      children_loader: -> { [archived_child, active_child] }
    )

    expect(project_health.health).to eq(:on_track)
  end

  it 'returns :not_available when children have unknown health values' do
    children = [
      double('Child', health: :unknown_value),
      double('Child', health: :another_unknown)
    ]
    project_health = described_class.new(
      health_updates_loader: -> { [] },
      weekly_health_updates_loader: -> { [] },
      children_loader: -> { children }
    )

    expect(project_health.health).to eq(:not_available)
  end

  describe 'health_trend' do
    it 'returns only current health when no weekly updates exist for leaf' do
      project_health = described_class.new(
        health_updates_loader: -> { [] },
        weekly_health_updates_loader: -> { [] },
        children_loader: -> { [] }
      )

      current_date = Date.respond_to?(:current) ? Date.current : Date.today
      trend = project_health.health_trend

      expect(trend.length).to eq(1)
      expect(trend[0].date).to eq(current_date)
      expect(trend[0].health).to eq(:not_available)
    end

    it 'returns only current health when weekly_health_updates_loader is nil' do
      project_health = described_class.new(
        health_updates_loader: -> { [] },
        weekly_health_updates_loader: nil,
        children_loader: -> { [] }
      )

      current_date = Date.respond_to?(:current) ? Date.current : Date.today
      trend = project_health.health_trend

      expect(trend.length).to eq(1)
      expect(trend[0].date).to eq(current_date)
      expect(trend[0].health).to eq(:not_available)
    end

    it 'returns weekly updates plus current health for leaf' do
      current_date = Date.respond_to?(:current) ? Date.current : Date.today
      weekly_updates = [
        double('HealthUpdate', date: Date.new(2025, 1, 5), health: :on_track),
        double('HealthUpdate', date: Date.new(2025, 1, 12), health: :at_risk)
      ]
      health_updates = [
        double('HealthUpdate', date: Date.new(2025, 1, 12), health: :at_risk, description: 'Some update')
      ]
      project_health = described_class.new(
        health_updates_loader: -> { health_updates },
        weekly_health_updates_loader: -> { weekly_updates },
        children_loader: -> { [] }
      )

      trend = project_health.health_trend

      expect(trend.length).to eq(3)
      expect(trend[0].date).to eq(Date.new(2025, 1, 5))
      expect(trend[1].date).to eq(Date.new(2025, 1, 12))
      expect(trend[2].date).to eq(current_date)
      expect(trend[2].health).to eq(:at_risk)
      expect(trend[2].description).to eq('Some update')
    end

    it 'returns weekly rollups of children health plus current health for parent' do
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
      child1 = double('Child', health_trend: child1_trend, health: :on_track)
      child2 = double('Child', health_trend: child2_trend, health: :off_track)

      project_health = described_class.new(
        health_updates_loader: -> { [] },
        weekly_health_updates_loader: -> { [] },
        children_loader: -> { [child1, child2] }
      )

      trend = project_health.health_trend

      expect(trend.length).to eq(3)
      expect(trend[0].date).to eq(monday1)
      expect(trend[0].health).to eq(:at_risk)
      expect(trend[1].date).to eq(monday2)
      expect(trend[1].health).to eq(:at_risk)
      current_date = Date.respond_to?(:current) ? Date.current : Date.today
      expect(trend[2].date).to eq(current_date)
      expect(trend[2].health).to eq(:at_risk)
    end

    it 'includes all 6 historical weeks plus current for parent' do
      mondays = (1..6).map { |i| Date.new(2025, 1, 6) + (i * 7) }
      child_trend = mondays.map { |m| double('HealthUpdate', date: m, health: :on_track) }
      child = double('Child', health_trend: child_trend, health: :on_track)

      project_health = described_class.new(
        health_updates_loader: -> { [] },
        weekly_health_updates_loader: -> { [] },
        children_loader: -> { [child] }
      )

      trend = project_health.health_trend

      current_date = Date.respond_to?(:current) ? Date.current : Date.today
      expect(trend.length).to eq(7)
      expect(trend[0..5].map(&:date)).to eq(mondays)
      expect(trend[6].date).to eq(current_date)
      expect(trend[6].health).to eq(:on_track)
    end

    it 'returns only current health for parent when children have no trends' do
      child = double('Child', health_trend: [], health: :on_track)
      project_health = described_class.new(
        health_updates_loader: -> { [] },
        weekly_health_updates_loader: -> { [] },
        children_loader: -> { [child] }
      )

      trend = project_health.health_trend

      current_date = Date.respond_to?(:current) ? Date.current : Date.today
      expect(trend.length).to eq(1)
      expect(trend[0].health).to eq(:on_track)
      expect(trend[0].date).to eq(current_date)
    end

    it 'excludes future-dated weekly updates from leaf trend' do
      current_date = Date.respond_to?(:current) ? Date.current : Date.today
      updates = [
        double('HealthUpdate', date: current_date - 7, health: :on_track),
        double('HealthUpdate', date: current_date + 7, health: :off_track)
      ]
      project_health = described_class.new(
        health_updates_loader: -> { [] },
        weekly_health_updates_loader: -> { updates },
        children_loader: -> { [] }
      )

      trend = project_health.health_trend

      expect(trend.length).to eq(2)
      expect(trend[0].health).to eq(:on_track)
      expect(trend[1].date).to eq(current_date)
      expect(trend[1].health).to eq(:not_available)
    end

    it 'excludes future-dated weeks from parent trend' do
      current_date = Date.respond_to?(:current) ? Date.current : Date.today
      past_monday = current_date - 7
      future_monday = current_date + 7
      child_trend = [
        double('HealthUpdate', date: past_monday, health: :on_track),
        double('HealthUpdate', date: future_monday, health: :off_track)
      ]
      child = double('Child', health_trend: child_trend, health: :on_track)

      project_health = described_class.new(
        health_updates_loader: -> { [] },
        weekly_health_updates_loader: -> { [] },
        children_loader: -> { [child] }
      )

      trend = project_health.health_trend

      expect(trend.length).to eq(2)
      expect(trend[0].date).to eq(past_monday)
      expect(trend[1].date).to eq(current_date)
    end

    it 'returns only current health when all child trend dates are in the future' do
      current_date = Date.respond_to?(:current) ? Date.current : Date.today
      future_monday = current_date + 7
      child_trend = [
        double('HealthUpdate', date: future_monday, health: :on_track)
      ]
      child = double('Child', health_trend: child_trend, health: :on_track)

      project_health = described_class.new(
        health_updates_loader: -> { [] },
        weekly_health_updates_loader: -> { [] },
        children_loader: -> { [child] }
      )

      trend = project_health.health_trend

      expect(trend.length).to eq(1)
      expect(trend[0].date).to eq(current_date)
      expect(trend[0].health).to eq(:on_track)
    end

    it 'returns :off_track in weekly rollup when all children are off_track' do
      monday = Date.new(2025, 1, 6)
      child1_trend = [double('HealthUpdate', date: monday, health: :off_track)]
      child2_trend = [double('HealthUpdate', date: monday, health: :off_track)]
      child1 = double('Child', health_trend: child1_trend, health: :off_track)
      child2 = double('Child', health_trend: child2_trend, health: :off_track)

      project_health = described_class.new(
        health_updates_loader: -> { [] },
        weekly_health_updates_loader: -> { [] },
        children_loader: -> { [child1, child2] }
      )

      trend = project_health.health_trend

      expect(trend[0].health).to eq(:off_track)
    end

    it 'handles child missing data for a particular monday in parent trend' do
      monday1 = Date.new(2025, 1, 6)
      monday2 = Date.new(2025, 1, 13)
      child1_trend = [
        double('HealthUpdate', date: monday1, health: :on_track),
        double('HealthUpdate', date: monday2, health: :on_track)
      ]
      child2_trend = [
        double('HealthUpdate', date: monday2, health: :off_track)
      ]
      child1 = double('Child', health_trend: child1_trend, health: :on_track)
      child2 = double('Child', health_trend: child2_trend, health: :off_track)

      project_health = described_class.new(
        health_updates_loader: -> { [] },
        weekly_health_updates_loader: -> { [] },
        children_loader: -> { [child1, child2] }
      )

      trend = project_health.health_trend

      expect(trend.length).to eq(3)
      expect(trend[0].date).to eq(monday1)
      expect(trend[0].health).to eq(:on_track)
      expect(trend[1].date).to eq(monday2)
      expect(trend[1].health).to eq(:at_risk)
    end

    it 'returns :not_available in weekly rollup when children have unknown health values' do
      monday = Date.new(2025, 1, 6)
      child_trend = [double('HealthUpdate', date: monday, health: :unknown_value)]
      child = double('Child', health_trend: child_trend, health: :not_available)

      project_health = described_class.new(
        health_updates_loader: -> { [] },
        weekly_health_updates_loader: -> { [] },
        children_loader: -> { [child] }
      )

      trend = project_health.health_trend

      expect(trend[0].health).to eq(:not_available)
    end
  end

  describe 'latest_health_update' do
    it 'returns nil when there are no updates' do
      project_health = described_class.new(
        health_updates_loader: -> { [] },
        weekly_health_updates_loader: -> { [] },
        children_loader: -> { [] }
      )

      expect(project_health.latest_health_update).to be_nil
    end

    it 'returns the most recent non-future update' do
      current_date = Date.respond_to?(:current) ? Date.current : Date.today
      past_update = double('HealthUpdate', date: current_date - 1, health: :on_track, description: 'Past')
      future_update = double('HealthUpdate', date: current_date + 7, health: :off_track, description: 'Future')
      project_health = described_class.new(
        health_updates_loader: -> { [past_update, future_update] },
        weekly_health_updates_loader: -> { [] },
        children_loader: -> { [] }
      )

      expect(project_health.latest_health_update).to eq(past_update)
    end
  end

  describe 'health_updates_for_tooltip' do
    it 'returns nil when there are children' do
      child = double('Child')
      project_health = described_class.new(
        health_updates_loader: -> { [] },
        weekly_health_updates_loader: -> { [] },
        children_loader: -> { [child] }
      )

      expect(project_health.health_updates_for_tooltip).to be_nil
    end

    it 'returns health updates when there are no children' do
      updates = [double('HealthUpdate', date: Date.new(2025, 1, 1), health: :on_track)]
      project_health = described_class.new(
        health_updates_loader: -> { updates },
        weekly_health_updates_loader: -> { [] },
        children_loader: -> { [] }
      )

      expect(project_health.health_updates_for_tooltip).to eq(updates)
    end
  end

  describe 'children_health_for_tooltip' do
    it 'returns nil when there are no children' do
      project_health = described_class.new(
        health_updates_loader: -> { [] },
        weekly_health_updates_loader: -> { [] },
        children_loader: -> { [] }
      )

      expect(project_health.children_health_for_tooltip).to be_nil
    end

    it 'returns children with name and health when there are children' do
      child1 = double('Child', name: 'Child 1', health: :on_track)
      child2 = double('Child', name: 'Child 2', health: :off_track)

      project_health = described_class.new(
        health_updates_loader: -> { [] },
        weekly_health_updates_loader: -> { [] },
        children_loader: -> { [child1, child2] }
      )

      result = project_health.children_health_for_tooltip

      expect(result.length).to eq(2)
      expect(result[0].name).to eq('Child 1')
      expect(result[0].health).to eq(:on_track)
      expect(result[1].name).to eq('Child 2')
      expect(result[1].health).to eq(:off_track)
    end
  end
end
