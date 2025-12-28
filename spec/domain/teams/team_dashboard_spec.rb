require 'spec_helper'
require 'date'
require 'domain/teams/team_dashboard'
require 'domain/teams/team'
require 'domain/teams/team_attributes'
require 'domain/teams/team_loaders'
require 'domain/projects/project'
require 'domain/projects/project_attributes'
require 'domain/projects/project_loaders'
require 'domain/projects/health_update'
require_relative '../../support/project_builder'

RSpec.describe TeamDashboard do
  def build_project(name:, state: :in_progress, health: :on_track, archived: false)
    health_update = HealthUpdate.new(project_id: name, date: Date.today, health: health)
    ProjectBuilder.build(
      name: name,
      current_state: state,
      archived: archived,
      health_updates_loader: ->(_project) { [health_update] }
    )
  end

  def build_project_with_id(id:, name:, state: :in_progress, health_updates_loader: nil)
    attrs = ProjectAttributes.new(id: id, name: name, current_state: state)
    loaders = ProjectLoaders.new(health_updates: health_updates_loader)
    Project.new(attributes: attrs, loaders: loaders)
  end

  def build_project_without_health(name:, state: :in_progress, archived: false)
    ProjectBuilder.build(
      name: name,
      current_state: state,
      archived: archived,
      health_updates_loader: ->(_project) { [] }
    )
  end

  def build_team(name:, owned_projects: [], subordinate_teams: [])
    attrs = TeamAttributes.new(name: name)
    loaders = TeamLoaders.new(
      owned_projects: ->(_t) { owned_projects },
      subordinate_teams: ->(_t) { subordinate_teams }
    )
    Team.new(attributes: attrs, loaders: loaders)
  end

  describe '#health_summary' do
    it 'counts projects by health status' do
      projects = [
        build_project(name: 'A', health: :on_track),
        build_project(name: 'B', health: :on_track),
        build_project(name: 'C', health: :at_risk),
        build_project(name: 'D', health: :off_track)
      ]
      team = build_team(name: 'Test', owned_projects: projects)
      dashboard = described_class.new(team: team)

      summary = dashboard.health_summary

      expect(summary[:on_track]).to eq(2)
      expect(summary[:at_risk]).to eq(1)
      expect(summary[:off_track]).to eq(1)
    end

    it 'excludes archived projects' do
      projects = [
        build_project(name: 'Active', health: :on_track),
        build_project(name: 'Archived', health: :off_track, archived: true)
      ]
      team = build_team(name: 'Test', owned_projects: projects)
      dashboard = described_class.new(team: team)

      summary = dashboard.health_summary

      expect(summary[:on_track]).to eq(1)
      expect(summary[:off_track]).to eq(0)
    end

    it 'returns zeros for empty team' do
      team = build_team(name: 'Empty', owned_projects: [])
      dashboard = described_class.new(team: team)

      summary = dashboard.health_summary

      expect(summary[:on_track]).to eq(0)
      expect(summary[:at_risk]).to eq(0)
      expect(summary[:off_track]).to eq(0)
    end

    it 'counts leaf descendants instead of parent projects' do
      child1_update = HealthUpdate.new(project_id: 'Child1', date: Date.today, health: :on_track)
      child2_update = HealthUpdate.new(project_id: 'Child2', date: Date.today, health: :at_risk)

      child1 = ProjectBuilder.build(
        name: 'Child1',
        current_state: :in_progress,
        health_updates_loader: ->(_p) { [child1_update] }
      )
      child2 = ProjectBuilder.build(
        name: 'Child2',
        current_state: :in_progress,
        health_updates_loader: ->(_p) { [child2_update] }
      )

      parent = ProjectBuilder.build(
        name: 'Parent',
        current_state: :in_progress,
        children_loader: ->(_p) { [child1, child2] },
        health_updates_loader: ->(_p) { [] }
      )

      team = build_team(name: 'Test', owned_projects: [parent])
      dashboard = described_class.new(team: team)

      summary = dashboard.health_summary

      expect(summary[:on_track]).to eq(1)
      expect(summary[:at_risk]).to eq(1)
      expect(summary[:off_track]).to eq(0)
    end
  end

  describe '#total_active_projects' do
    it 'counts only in_progress and blocked projects' do
      projects = [
        build_project(name: 'A', state: :in_progress),
        build_project(name: 'B', state: :blocked),
        build_project(name: 'C', state: :new),
        build_project(name: 'D', state: :todo),
        build_project(name: 'E', state: :on_hold),
        build_project(name: 'F', state: :done)
      ]
      team = build_team(name: 'Test', owned_projects: projects)
      dashboard = described_class.new(team: team)

      expect(dashboard.total_active_projects).to eq(2)
    end

    it 'excludes archived projects' do
      projects = [
        build_project(name: 'Active', state: :in_progress),
        build_project(name: 'Archived', state: :in_progress, archived: true)
      ]
      team = build_team(name: 'Test', owned_projects: projects)
      dashboard = described_class.new(team: team)

      expect(dashboard.total_active_projects).to eq(1)
    end

    it 'returns zero for empty team' do
      team = build_team(name: 'Empty', owned_projects: [])
      dashboard = described_class.new(team: team)

      expect(dashboard.total_active_projects).to eq(0)
    end
  end

  describe '#attention_required' do
    it 'returns off-track projects' do
      projects = [
        build_project(name: 'Fine', health: :on_track, state: :in_progress),
        build_project(name: 'Problem', health: :off_track, state: :in_progress)
      ]
      team = build_team(name: 'Test', owned_projects: projects)
      dashboard = described_class.new(team: team)

      attention = dashboard.attention_required

      expect(attention.map(&:name)).to eq(['Problem'])
    end

    it 'returns blocked projects' do
      projects = [
        build_project(name: 'Fine', health: :on_track, state: :in_progress),
        build_project(name: 'Stuck', health: :on_track, state: :blocked)
      ]
      team = build_team(name: 'Test', owned_projects: projects)
      dashboard = described_class.new(team: team)

      attention = dashboard.attention_required

      expect(attention.map(&:name)).to eq(['Stuck'])
    end

    it 'returns at-risk projects' do
      projects = [
        build_project(name: 'Fine', health: :on_track, state: :in_progress),
        build_project(name: 'Risky', health: :at_risk, state: :in_progress)
      ]
      team = build_team(name: 'Test', owned_projects: projects)
      dashboard = described_class.new(team: team)

      attention = dashboard.attention_required

      expect(attention.map(&:name)).to eq(['Risky'])
    end

    it 'excludes archived and non-working projects' do
      projects = [
        build_project(name: 'Archived', health: :off_track, archived: true),
        build_project(name: 'Done', health: :off_track, state: :done),
        build_project(name: 'OnHold', health: :off_track, state: :on_hold),
        build_project(name: 'New', health: :off_track, state: :new),
        build_project(name: 'Todo', health: :off_track, state: :todo)
      ]
      team = build_team(name: 'Test', owned_projects: projects)
      dashboard = described_class.new(team: team)

      attention = dashboard.attention_required

      expect(attention).to be_empty
    end

    it 'sorts by health severity then name' do
      projects = [
        build_project(name: 'B Risk', health: :at_risk, state: :in_progress),
        build_project(name: 'A Off', health: :off_track, state: :in_progress),
        build_project(name: 'Z Off', health: :off_track, state: :in_progress)
      ]
      team = build_team(name: 'Test', owned_projects: projects)
      dashboard = described_class.new(team: team)

      attention = dashboard.attention_required

      expect(attention.map(&:name)).to eq(['A Off', 'Z Off', 'B Risk'])
    end
  end

  describe '#on_hold_projects' do
    it 'returns projects with on_hold state' do
      projects = [
        build_project(name: 'OnHold', state: :on_hold),
        build_project(name: 'InProgress', state: :in_progress)
      ]
      team = build_team(name: 'Test', owned_projects: projects)
      dashboard = described_class.new(team: team)

      result = dashboard.on_hold_projects

      expect(result.map(&:name)).to eq(['OnHold'])
    end

    it 'excludes archived projects' do
      projects = [
        build_project(name: 'OnHoldArchived', state: :on_hold, archived: true)
      ]
      team = build_team(name: 'Test', owned_projects: projects)
      dashboard = described_class.new(team: team)

      result = dashboard.on_hold_projects

      expect(result).to be_empty
    end
  end

  describe '#never_updated_projects' do
    it 'returns projects with not_available health' do
      projects = [
        build_project_without_health(name: 'NotAvailable'),
        build_project(name: 'Updated', health: :on_track)
      ]
      team = build_team(name: 'Test', owned_projects: projects)
      dashboard = described_class.new(team: team)

      result = dashboard.never_updated_projects

      expect(result.map(&:name)).to eq(['NotAvailable'])
    end

    it 'excludes archived and non-working projects' do
      projects = [
        build_project_without_health(name: 'Archived', archived: true),
        build_project_without_health(name: 'Done', state: :done),
        build_project_without_health(name: 'OnHold', state: :on_hold),
        build_project_without_health(name: 'New', state: :new),
        build_project_without_health(name: 'Todo', state: :todo)
      ]
      team = build_team(name: 'Test', owned_projects: projects)
      dashboard = described_class.new(team: team)

      result = dashboard.never_updated_projects

      expect(result).to be_empty
    end
  end

  describe '#stale_projects' do
    it 'returns projects with no health update in the given days' do
      fresh_update = HealthUpdate.new(project_id: 'fresh', date: Date.today - 5, health: :on_track)
      stale_update = HealthUpdate.new(project_id: 'stale', date: Date.today - 20, health: :on_track)

      fresh_project = build_project_with_id(
        id: 'fresh',
        name: 'Fresh',
        health_updates_loader: ->(_p) { [fresh_update] }
      )
      stale_project = build_project_with_id(
        id: 'stale',
        name: 'Stale',
        health_updates_loader: ->(_p) { [stale_update] }
      )

      health_repo = double('HealthUpdateRepository')
      allow(health_repo).to receive(:latest_for_project).with('fresh').and_return(fresh_update)
      allow(health_repo).to receive(:latest_for_project).with('stale').and_return(stale_update)

      team = build_team(name: 'Test', owned_projects: [fresh_project, stale_project])
      dashboard = described_class.new(team: team, health_update_repository: health_repo)

      stale = dashboard.stale_projects(days: 14)

      expect(stale.map(&:name)).to eq(['Stale'])
    end

    it 'excludes projects with no health updates' do
      projects = [build_project_without_health(name: 'NoUpdates')]
      health_repo = double('HealthUpdateRepository')
      allow(health_repo).to receive(:latest_for_project).with('NoUpdates').and_return(nil)

      team = build_team(name: 'Test', owned_projects: projects)
      dashboard = described_class.new(team: team, health_update_repository: health_repo)

      stale = dashboard.stale_projects(days: 14)

      expect(stale).to be_empty
    end

    it 'excludes archived and non-working projects' do
      old_update = HealthUpdate.new(project_id: 'test', date: Date.today - 20, health: :on_track)

      projects = [
        build_project(name: 'Archived', archived: true),
        build_project(name: 'Done', state: :done),
        build_project(name: 'OnHold', state: :on_hold),
        build_project(name: 'New', state: :new),
        build_project(name: 'Todo', state: :todo)
      ]

      health_repo = double('HealthUpdateRepository')
      allow(health_repo).to receive(:latest_for_project).and_return(old_update)

      team = build_team(name: 'Test', owned_projects: projects)
      dashboard = described_class.new(team: team, health_update_repository: health_repo)

      stale = dashboard.stale_projects(days: 14)

      expect(stale).to be_empty
    end

    it 'returns empty when health_update_repository is nil' do
      projects = [build_project(name: 'Test')]
      team = build_team(name: 'Test', owned_projects: projects)
      dashboard = described_class.new(team: team, health_update_repository: nil)

      stale = dashboard.stale_projects(days: 14)

      expect(stale).to be_empty
    end

    it 'uses project id when available' do
      update = HealthUpdate.new(project_id: 'test-id', date: Date.today - 20, health: :on_track)
      project = build_project_with_id(
        id: 'test-id',
        name: 'WithId',
        health_updates_loader: ->(_p) { [update] }
      )

      health_repo = double('HealthUpdateRepository')
      allow(health_repo).to receive(:latest_for_project).with('test-id').and_return(update)

      team = build_team(name: 'Test', owned_projects: [project])
      dashboard = described_class.new(team: team, health_update_repository: health_repo)

      stale = dashboard.stale_projects(days: 14)

      expect(stale.map(&:name)).to eq(['WithId'])
    end

    it 'falls back to project name when id is nil' do
      update = HealthUpdate.new(project_id: 'NoIdProject', date: Date.today - 20, health: :on_track)
      project = build_project(name: 'NoIdProject')

      health_repo = double('HealthUpdateRepository')
      allow(health_repo).to receive(:latest_for_project).with('NoIdProject').and_return(update)

      team = build_team(name: 'Test', owned_projects: [project])
      dashboard = described_class.new(team: team, health_update_repository: health_repo)

      stale = dashboard.stale_projects(days: 14)

      expect(stale.map(&:name)).to eq(['NoIdProject'])
    end
  end

  describe '#stale_projects_between' do
    it 'returns projects with updates between min and max days ago' do
      update_10_days = HealthUpdate.new(project_id: 'ten', date: Date.today - 10, health: :on_track)
      update_20_days = HealthUpdate.new(project_id: 'twenty', date: Date.today - 20, health: :on_track)
      update_3_days = HealthUpdate.new(project_id: 'three', date: Date.today - 3, health: :on_track)

      project_10 = build_project_with_id(id: 'ten', name: 'TenDays', health_updates_loader: ->(_p) { [update_10_days] })
      project_20 = build_project_with_id(id: 'twenty', name: 'TwentyDays', health_updates_loader: ->(_p) { [update_20_days] })
      project_3 = build_project_with_id(id: 'three', name: 'ThreeDays', health_updates_loader: ->(_p) { [update_3_days] })

      health_repo = double('HealthUpdateRepository')
      allow(health_repo).to receive(:latest_for_project).with('ten').and_return(update_10_days)
      allow(health_repo).to receive(:latest_for_project).with('twenty').and_return(update_20_days)
      allow(health_repo).to receive(:latest_for_project).with('three').and_return(update_3_days)

      team = build_team(name: 'Test', owned_projects: [project_10, project_20, project_3])
      dashboard = described_class.new(team: team, health_update_repository: health_repo)

      stale = dashboard.stale_projects_between(min_days: 7, max_days: 14)

      expect(stale.map(&:name)).to eq(['TenDays'])
    end

    it 'excludes projects with no health updates' do
      projects = [build_project_without_health(name: 'NoUpdates')]
      health_repo = double('HealthUpdateRepository')
      allow(health_repo).to receive(:latest_for_project).with('NoUpdates').and_return(nil)

      team = build_team(name: 'Test', owned_projects: projects)
      dashboard = described_class.new(team: team, health_update_repository: health_repo)

      stale = dashboard.stale_projects_between(min_days: 7, max_days: 14)

      expect(stale).to be_empty
    end

    it 'returns empty when health_update_repository is nil' do
      projects = [build_project(name: 'Test')]
      team = build_team(name: 'Test', owned_projects: projects)
      dashboard = described_class.new(team: team, health_update_repository: nil)

      stale = dashboard.stale_projects_between(min_days: 7, max_days: 14)

      expect(stale).to be_empty
    end
  end

end
