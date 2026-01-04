require 'spec_helper'
require 'domain/projects/project'
require 'domain/projects/project_attributes'
require 'domain/projects/project_loaders'

RSpec.describe Project do
  def build_project(name:, description: '', point_of_contact: '', archived: false, current_state: :new,
                    children_loader: nil, parent_loader: nil, health_updates_loader: nil, weekly_health_updates_loader: nil,
                    owning_team_loader: nil, current_date: Date.today)
    attrs = ProjectAttributes.new(
      name: name,
      description: description,
      point_of_contact: point_of_contact,
      archived: archived,
      current_state: current_state
    )
    loaders = ProjectLoaders.new(
      children: children_loader,
      parent: parent_loader,
      health_updates: health_updates_loader,
      weekly_health_updates: weekly_health_updates_loader,
      owning_team: owning_team_loader,
      current_date: current_date
    )
    described_class.new(attributes: attrs, loaders: loaders)
  end

  it 'is valid when it has a name' do
    project = build_project(name: 'Status')

    expect(project.valid?).to be(true)
  end

  it 'is invalid when its name is blank' do
    project = build_project(name: '')

    expect(project.valid?).to be(false)
  end

  it 'lazy loads children via the loader' do
    loader = ->(_project) { [build_project(name: 'Child')] }
    project = build_project(name: 'Parent', children_loader: loader)

    expect(project.children.map(&:name)).to eq(['Child'])
  end

  it 'lazy loads parent via the loader' do
    parent = build_project(name: 'Parent')
    loader = ->(_project) { parent }
    project = build_project(name: 'Child', parent_loader: loader)

    expect(project.parent).to eq(parent)
  end

  it 'returns nil parent when no loader provided' do
    project = build_project(name: 'Child')

    expect(project.parent).to be_nil
  end

  it 'defaults current_state to :new' do
    project = build_project(name: 'Status')

    expect(project.current_state).to eq(:new)
  end

  it 'is invalid when initialized with an invalid state' do
    project = build_project(name: 'Status', current_state: :invalid)

    expect(project.valid?).to be(false)
    expect(project.errors).to include('state must be valid')
  end

  it 'returns a new project when updating state' do
    project = build_project(name: 'Status')

    updated = project.with_state(state: :todo)

    expect(updated.current_state).to eq(:todo)
    expect(updated).not_to equal(project)
  end

  describe 'leaf?' do
    it 'returns true when project has no children' do
      project = build_project(name: 'Leaf', children_loader: ->(_) { [] })

      expect(project.leaf?).to be(true)
    end

    it 'returns true when children_loader is nil' do
      project = build_project(name: 'Leaf')

      expect(project.leaf?).to be(true)
    end

    it 'returns false when project has children' do
      child = build_project(name: 'Child')
      project = build_project(name: 'Parent', children_loader: ->(_) { [child] })

      expect(project.leaf?).to be(false)
    end
  end

  describe 'leaf_descendants' do
    it 'returns itself when project is a leaf' do
      project = build_project(name: 'Leaf', children_loader: ->(_) { [] })

      expect(project.leaf_descendants).to eq([project])
    end

    it 'returns direct children when they are all leaves' do
      child1 = build_project(name: 'Child1', children_loader: ->(_) { [] })
      child2 = build_project(name: 'Child2', children_loader: ->(_) { [] })
      parent = build_project(name: 'Parent', children_loader: ->(_) { [child1, child2] })

      expect(parent.leaf_descendants).to eq([child1, child2])
    end

    it 'returns grandchildren when children are parents' do
      grandchild1 = build_project(name: 'GC1', children_loader: ->(_) { [] })
      grandchild2 = build_project(name: 'GC2', children_loader: ->(_) { [] })
      child = build_project(name: 'Child', children_loader: ->(_) { [grandchild1, grandchild2] })
      grandparent = build_project(name: 'Grandparent', children_loader: ->(_) { [child] })

      expect(grandparent.leaf_descendants).to eq([grandchild1, grandchild2])
    end

    it 'returns mixed leaves from different levels' do
      grandchild = build_project(name: 'GC', children_loader: ->(_) { [] })
      parent_child = build_project(name: 'ParentChild', children_loader: ->(_) { [grandchild] })
      leaf_child = build_project(name: 'LeafChild', children_loader: ->(_) { [] })
      root = build_project(name: 'Root', children_loader: ->(_) { [parent_child, leaf_child] })

      expect(root.leaf_descendants).to eq([grandchild, leaf_child])
    end
  end

  describe 'derived state for parent projects' do
    it 'returns stored state for leaf projects' do
      project = build_project(name: 'Leaf', current_state: :in_progress, children_loader: ->(_) { [] })

      expect(project.current_state).to eq(:in_progress)
    end

    it 'returns :blocked when any leaf is blocked' do
      child1 = build_project(name: 'C1', current_state: :blocked, children_loader: ->(_) { [] })
      child2 = build_project(name: 'C2', current_state: :in_progress, children_loader: ->(_) { [] })
      parent = build_project(name: 'Parent', children_loader: ->(_) { [child1, child2] })

      expect(parent.current_state).to eq(:blocked)
    end

    it 'returns :in_progress when any leaf is in_progress and none blocked' do
      child1 = build_project(name: 'C1', current_state: :in_progress, children_loader: ->(_) { [] })
      child2 = build_project(name: 'C2', current_state: :done, children_loader: ->(_) { [] })
      parent = build_project(name: 'Parent', children_loader: ->(_) { [child1, child2] })

      expect(parent.current_state).to eq(:in_progress)
    end

    it 'returns :on_hold when any leaf is on_hold and none blocked/in_progress' do
      child1 = build_project(name: 'C1', current_state: :on_hold, children_loader: ->(_) { [] })
      child2 = build_project(name: 'C2', current_state: :done, children_loader: ->(_) { [] })
      parent = build_project(name: 'Parent', children_loader: ->(_) { [child1, child2] })

      expect(parent.current_state).to eq(:on_hold)
    end

    it 'returns :todo when any leaf is todo and none blocked/in_progress/on_hold' do
      child1 = build_project(name: 'C1', current_state: :todo, children_loader: ->(_) { [] })
      child2 = build_project(name: 'C2', current_state: :done, children_loader: ->(_) { [] })
      parent = build_project(name: 'Parent', children_loader: ->(_) { [child1, child2] })

      expect(parent.current_state).to eq(:todo)
    end

    it 'returns :new when any leaf is new and none blocked/in_progress/on_hold/todo' do
      child1 = build_project(name: 'C1', current_state: :new, children_loader: ->(_) { [] })
      child2 = build_project(name: 'C2', current_state: :done, children_loader: ->(_) { [] })
      parent = build_project(name: 'Parent', children_loader: ->(_) { [child1, child2] })

      expect(parent.current_state).to eq(:new)
    end

    it 'returns :done when all leaves are done' do
      child1 = build_project(name: 'C1', current_state: :done, children_loader: ->(_) { [] })
      child2 = build_project(name: 'C2', current_state: :done, children_loader: ->(_) { [] })
      parent = build_project(name: 'Parent', children_loader: ->(_) { [child1, child2] })

      expect(parent.current_state).to eq(:done)
    end

    it 'rolls up state from grandchildren' do
      grandchild = build_project(name: 'GC', current_state: :blocked, children_loader: ->(_) { [] })
      child = build_project(name: 'Child', children_loader: ->(_) { [grandchild] })
      grandparent = build_project(name: 'GP', children_loader: ->(_) { [child] })

      expect(grandparent.current_state).to eq(:blocked)
    end

    it 'returns :new when parent has no children' do
      parent = build_project(name: 'Parent', children_loader: ->(_) { [] })

      expect(parent.current_state).to eq(:new)
    end

    it 'returns :new when leaf_descendants returns empty due to stubbing' do
      child = build_project(name: 'Child', children_loader: ->(_) { [] })
      parent = build_project(name: 'Parent', children_loader: ->(_) { [child] })
      allow(parent).to receive(:leaf_descendants).and_return([])

      expect(parent.current_state).to eq(:new)
    end
  end

  describe 'health' do
    it 'returns :not_available for leaf with no health updates' do
      project = build_project(
        name: 'Status',
        children_loader: ->(_) { [] },
        health_updates_loader: ->(_) { [] }
      )

      expect(project.health).to eq(:not_available)
    end

    it 'returns :not_available when health_updates_loader is nil' do
      project = build_project(
        name: 'Status',
        children_loader: ->(_) { [] }
      )

      expect(project.health).to eq(:not_available)
    end

    it 'returns the latest health for leaf with updates' do
      updates = [
        double('HealthUpdate', date: Date.new(2025, 1, 1), health: :on_track),
        double('HealthUpdate', date: Date.new(2025, 1, 8), health: :at_risk)
      ]
      project = build_project(
        name: 'Status',
        children_loader: ->(_) { [] },
        health_updates_loader: ->(_) { updates },
        weekly_health_updates_loader: ->(_) { updates }
      )

      expect(project.health).to eq(:at_risk)
    end

    it 'rolls up health from subordinate projects' do
      children = [
        double('Project', health: :on_track, archived?: false, current_state: :in_progress),
        double('Project', health: :off_track, archived?: false, current_state: :in_progress)
      ]
      project = build_project(
        name: 'Status',
        children_loader: ->(_) { children },
        health_updates_loader: ->(_) { [] }
      )

      expect(project.health).to eq(:at_risk)
    end

    it 'ignores :not_available subordinate health values' do
      children = [
        double('Project', health: :not_available, archived?: false, current_state: :in_progress),
        double('Project', health: :on_track, archived?: false, current_state: :in_progress)
      ]
      project = build_project(
        name: 'Status',
        children_loader: ->(_) { children },
        health_updates_loader: ->(_) { [] }
      )

      expect(project.health).to eq(:on_track)
    end

    it 'returns :not_available when all subordinates have :not_available health' do
      children = [
        double('Project', health: :not_available, archived?: false, current_state: :in_progress),
        double('Project', health: :not_available, archived?: false, current_state: :in_progress)
      ]
      project = build_project(
        name: 'Status',
        children_loader: ->(_) { children },
        health_updates_loader: ->(_) { [] }
      )

      expect(project.health).to eq(:not_available)
    end

    it 'returns :off_track when all subordinates are off_track' do
      children = [
        double('Project', health: :off_track, archived?: false, current_state: :in_progress),
        double('Project', health: :off_track, archived?: false, current_state: :in_progress)
      ]
      project = build_project(
        name: 'Status',
        children_loader: ->(_) { children },
        health_updates_loader: ->(_) { [] }
      )

      expect(project.health).to eq(:off_track)
    end

    it 'excludes future-dated health updates from current health' do
      updates = [
        double('HealthUpdate', date: Date.today - 7, health: :on_track),
        double('HealthUpdate', date: Date.today + 7, health: :off_track)
      ]
      project = build_project(
        name: 'Status',
        children_loader: ->(_) { [] },
        health_updates_loader: ->(_) { updates },
        weekly_health_updates_loader: ->(_) { [] }
      )

      expect(project.health).to eq(:on_track)
    end

    it 'returns :not_available when subordinates have unknown health values' do
      children = [
        double('Project', health: :unknown_value, archived?: false, current_state: :in_progress),
        double('Project', health: :another_unknown, archived?: false, current_state: :in_progress)
      ]
      project = build_project(
        name: 'Status',
        children_loader: ->(_) { children },
        health_updates_loader: ->(_) { [] }
      )

      expect(project.health).to eq(:not_available)
    end
  end

  describe '#latest_health_update' do
    it 'returns nil when project has no updates' do
      project = build_project(
        name: 'Status',
        children_loader: ->(_) { [] },
        health_updates_loader: ->(_) { [] }
      )

      expect(project.latest_health_update).to be_nil
    end

    it 'returns the most recent non-future update' do
      current_date = Date.today
      past_update = double('HealthUpdate', date: current_date - 1, health: :on_track, description: 'Past')
      future_update = double('HealthUpdate', date: current_date + 3, health: :off_track, description: 'Future')
      project = build_project(
        name: 'Status',
        children_loader: ->(_) { [] },
        health_updates_loader: ->(_) { [past_update, future_update] },
        weekly_health_updates_loader: ->(_) { [] }
      )

      expect(project.latest_health_update).to eq(past_update)
    end
  end

  describe 'health_trend' do
    it 'returns only current health when no weekly updates exist for leaf project' do
      loader = ->(_project) { [] }
      project = build_project(
        name: 'Status',
        children_loader: loader,
        health_updates_loader: loader,
        weekly_health_updates_loader: loader
      )

      current_date = Date.today
      trend = project.health_trend

      expect(trend.length).to eq(1)
      expect(trend[0].date).to eq(current_date)
      expect(trend[0].health).to eq(:not_available)
    end

    it 'returns only current health when weekly_health_updates_loader is nil' do
      project = build_project(
        name: 'Status',
        children_loader: ->(_) { [] },
        health_updates_loader: ->(_) { [] }
      )

      current_date = Date.today
      trend = project.health_trend

      expect(trend.length).to eq(1)
      expect(trend[0].date).to eq(current_date)
      expect(trend[0].health).to eq(:not_available)
    end

    it 'returns weekly updates plus current health for leaf project' do
      current_date = Date.today
      weekly_updates = [
        double('HealthUpdate', date: Date.new(2025, 1, 5), health: :on_track),
        double('HealthUpdate', date: Date.new(2025, 1, 12), health: :at_risk)
      ]
      health_updates = [
        double('HealthUpdate', date: Date.new(2025, 1, 12), health: :at_risk, description: 'Some update')
      ]
      project = build_project(
        name: 'Status',
        children_loader: ->(_) { [] },
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
      child1 = double('Project', health_trend: child1_trend, health: :on_track, archived?: false, current_state: :in_progress)
      child2 = double('Project', health_trend: child2_trend, health: :off_track, archived?: false, current_state: :in_progress)

      project = build_project(
        name: 'Parent',
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
      current_date = Date.today
      expect(trend[2].date).to eq(current_date)
      expect(trend[2].health).to eq(:at_risk)
    end

    it 'includes all 6 historical weeks plus current for parent project' do
      mondays = (1..6).map { |i| Date.new(2025, 1, 6) + (i * 7) }
      child_trend = mondays.map { |m| double('HealthUpdate', date: m, health: :on_track) }
      child = double('Project', health_trend: child_trend, health: :on_track, archived?: false, current_state: :in_progress)

      project = build_project(
        name: 'Parent',
        children_loader: ->(_) { [child] },
        health_updates_loader: ->(_) { [] },
        weekly_health_updates_loader: ->(_) { [] }
      )

      trend = project.health_trend

      current_date = Date.today
      expect(trend.length).to eq(7)
      expect(trend[0..5].map(&:date)).to eq(mondays)
      expect(trend[6].date).to eq(current_date)
      expect(trend[6].health).to eq(:on_track)
    end

    it 'returns only current health for parent when children have no trends' do
      child = double('Project', health_trend: [], health: :on_track, archived?: false, current_state: :in_progress)
      project = build_project(
        name: 'Parent',
        children_loader: ->(_) { [child] },
        health_updates_loader: ->(_) { [] },
        weekly_health_updates_loader: ->(_) { [] }
      )

      trend = project.health_trend

      current_date = Date.today
      expect(trend.length).to eq(1)
      expect(trend[0].health).to eq(:on_track)
      expect(trend[0].date).to eq(current_date)
    end

    it 'excludes future-dated weekly updates from leaf project trend' do
      current_date = Date.today
      updates = [
        double('HealthUpdate', date: current_date - 7, health: :on_track),
        double('HealthUpdate', date: current_date + 7, health: :off_track)
      ]
      project = build_project(
        name: 'Status',
        children_loader: ->(_) { [] },
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
      current_date = Date.today
      past_monday = current_date - 7
      future_monday = current_date + 7
      child_trend = [
        double('HealthUpdate', date: past_monday, health: :on_track),
        double('HealthUpdate', date: future_monday, health: :off_track)
      ]
      child = double('Project', health_trend: child_trend, health: :on_track, archived?: false, current_state: :in_progress)

      project = build_project(
        name: 'Parent',
        children_loader: ->(_) { [child] },
        health_updates_loader: ->(_) { [] },
        weekly_health_updates_loader: ->(_) { [] }
      )

      trend = project.health_trend

      expect(trend.length).to eq(2)
      expect(trend[0].date).to eq(past_monday)
      expect(trend[1].date).to eq(current_date)
    end

    it 'returns only current health when all child trend dates are in the future' do
      current_date = Date.today
      future_monday = current_date + 7
      child_trend = [
        double('HealthUpdate', date: future_monday, health: :on_track)
      ]
      child = double('Project', health_trend: child_trend, health: :on_track, archived?: false, current_state: :in_progress)

      project = build_project(
        name: 'Parent',
        children_loader: ->(_) { [child] },
        health_updates_loader: ->(_) { [] },
        weekly_health_updates_loader: ->(_) { [] }
      )

      trend = project.health_trend

      expect(trend.length).to eq(1)
      expect(trend[0].date).to eq(current_date)
      expect(trend[0].health).to eq(:on_track)
    end

    it 'returns :off_track in weekly rollup when all children are off_track' do
      monday = Date.new(2025, 1, 6)
      child1_trend = [double('HealthUpdate', date: monday, health: :off_track)]
      child2_trend = [double('HealthUpdate', date: monday, health: :off_track)]
      child1 = double('Project', health_trend: child1_trend, health: :off_track, archived?: false, current_state: :in_progress)
      child2 = double('Project', health_trend: child2_trend, health: :off_track, archived?: false, current_state: :in_progress)

      project = build_project(
        name: 'Parent',
        children_loader: ->(_) { [child1, child2] },
        health_updates_loader: ->(_) { [] },
        weekly_health_updates_loader: ->(_) { [] }
      )

      trend = project.health_trend

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
      child1 = double('Project', health_trend: child1_trend, health: :on_track, archived?: false, current_state: :in_progress)
      child2 = double('Project', health_trend: child2_trend, health: :off_track, archived?: false, current_state: :in_progress)

      project = build_project(
        name: 'Parent',
        children_loader: ->(_) { [child1, child2] },
        health_updates_loader: ->(_) { [] },
        weekly_health_updates_loader: ->(_) { [] }
      )

      trend = project.health_trend

      expect(trend.length).to eq(3)
      expect(trend[0].date).to eq(monday1)
      expect(trend[0].health).to eq(:on_track)
      expect(trend[1].date).to eq(monday2)
      expect(trend[1].health).to eq(:at_risk)
    end

    it 'returns :not_available in weekly rollup when children have unknown health values' do
      monday = Date.new(2025, 1, 6)
      child_trend = [double('HealthUpdate', date: monday, health: :unknown_value)]
      child = double('Project', health_trend: child_trend, health: :not_available, archived?: false, current_state: :in_progress )

      project = build_project(
        name: 'Parent',
        children_loader: ->(_) { [child] },
        health_updates_loader: ->(_) { [] },
        weekly_health_updates_loader: ->(_) { [] }
      )

      trend = project.health_trend

      expect(trend[0].health).to eq(:not_available)
    end
  end

  describe 'health_updates_for_tooltip' do
    it 'returns nil when project has children' do
      child = build_project(name: 'Child', children_loader: ->(_) { [] })
      project = build_project(
        name: 'Parent',
        children_loader: ->(_) { [child] },
        health_updates_loader: ->(_) { [] }
      )

      expect(project.health_updates_for_tooltip).to be_nil
    end

    it 'returns health updates when project has no children' do
      updates = [double('HealthUpdate', date: Date.new(2025, 1, 1), health: :on_track)]
      project = build_project(
        name: 'Leaf',
        children_loader: ->(_) { [] },
        health_updates_loader: ->(_) { updates }
      )

      expect(project.health_updates_for_tooltip).to eq(updates)
    end
  end

  describe 'children_health_for_tooltip' do
    it 'returns nil when project has no children' do
      project = build_project(
        name: 'Status',
        current_state: :in_progress,
        children_loader: ->(_) { [] }
      )

      expect(project.children_health_for_tooltip).to be_nil
    end

    it 'returns children with name and health when project has children' do
      child1 = build_project(name: 'Child 1', current_state: :in_progress)
      child2 = build_project(name: 'Child 2', current_state: :blocked)
      allow(child1).to receive(:health).and_return(:on_track)
      allow(child2).to receive(:health).and_return(:off_track)

      project = build_project(
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
      child1 = build_project(name: 'Active', current_state: :in_progress)
      child2 = build_project(name: 'Done', current_state: :done)
      allow(child1).to receive(:health).and_return(:on_track)
      allow(child2).to receive(:health).and_return(:not_available)

      project = build_project(
        name: 'Parent',
        current_state: :in_progress,
        children_loader: ->(_) { [child1, child2] }
      )

      result = project.children_health_for_tooltip

      expect(result.length).to eq(2)
      expect(result.map(&:name)).to eq(['Active', 'Done'])
    end
  end

  describe '#owning_team' do
    it 'returns nil when no loader provided' do
      project = build_project(name: 'Status')

      expect(project.owning_team).to be_nil
    end

    it 'lazy loads owning team via the loader' do
      team = double('Team', name: 'Platform')
      project = build_project(name: 'Status', owning_team_loader: ->(_p) { team })

      expect(project.owning_team).to eq(team)
    end
  end

  describe '#effective_contact' do
    it 'returns own point_of_contact when present' do
      project = build_project(name: 'Status', point_of_contact: 'Alice')

      expect(project.effective_contact).to eq('Alice')
    end

    it 'returns parent point_of_contact when own is blank' do
      parent = build_project(name: 'Parent', point_of_contact: 'Bob')
      project = build_project(name: 'Child', point_of_contact: '', parent_loader: ->(_p) { parent })

      expect(project.effective_contact).to eq('Bob')
    end

    it 'traverses project hierarchy to find contact' do
      grandparent = build_project(name: 'Grandparent', point_of_contact: 'Carol')
      parent = build_project(name: 'Parent', point_of_contact: '', parent_loader: ->(_p) { grandparent })
      project = build_project(name: 'Child', point_of_contact: '', parent_loader: ->(_p) { parent })

      expect(project.effective_contact).to eq('Carol')
    end

    it 'uses owning team contact when project hierarchy has no contact' do
      team = double('Team', effective_contact: 'Dave')
      project = build_project(name: 'Status', point_of_contact: '', owning_team_loader: ->(_p) { team })

      expect(project.effective_contact).to eq('Dave')
    end

    it 'traverses project hierarchy before checking owning team' do
      parent = build_project(name: 'Parent', point_of_contact: 'Eve')
      team = double('Team', effective_contact: 'Frank')
      project = build_project(
        name: 'Child',
        point_of_contact: '',
        parent_loader: ->(_p) { parent },
        owning_team_loader: ->(_p) { team }
      )

      expect(project.effective_contact).to eq('Eve')
    end

    it 'returns nil when no contact found anywhere' do
      project = build_project(name: 'Status', point_of_contact: '')

      expect(project.effective_contact).to be_nil
    end
  end
end
