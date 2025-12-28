require 'spec_helper'
require 'date'
require 'domain/dashboard/dashboard'
require 'domain/projects/project'
require 'domain/projects/project_attributes'
require 'domain/projects/project_loaders'
require 'domain/projects/health_update'
require 'domain/initiatives/initiative'
require 'domain/teams/team'
require_relative '../../support/persistence/fake_project_repository'
require_relative '../../support/persistence/fake_health_update_repository'
require_relative '../../support/persistence/fake_initiative_repository'
require_relative '../../support/persistence/fake_team_repository'
require_relative '../../support/project_builder'

RSpec.describe Dashboard do
  def build_project(name:, state: :in_progress, health: :on_track, archived: false)
    health_update = HealthUpdate.new(project_id: name, date: Date.today, health: health)
    ProjectBuilder.build(
      name: name,
      current_state: state,
      archived: archived,
      health_updates_loader: ->(_project) { [health_update] }
    )
  end

  describe '#health_summary' do
    it 'counts projects by health status' do
      projects = [
        build_project(name: 'A', health: :on_track),
        build_project(name: 'B', health: :on_track),
        build_project(name: 'C', health: :at_risk),
        build_project(name: 'D', health: :off_track)
      ]
      project_repo = FakeProjectRepository.new
      projects.each { |p| project_repo.save(p) }
      dashboard = described_class.new(project_repository: project_repo)

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
      project_repo = FakeProjectRepository.new
      projects.each { |p| project_repo.save(p) }
      dashboard = described_class.new(project_repository: project_repo)

      summary = dashboard.health_summary

      expect(summary[:on_track]).to eq(1)
      expect(summary[:off_track]).to eq(0)
    end

    it 'excludes child projects from counts' do
      parent = build_project(name: 'Parent', health: :on_track)
      child = build_project(name: 'Child', health: :off_track)
      project_repo = FakeProjectRepository.new
      project_repo.save(parent)
      project_repo.save(child)
      project_repo.link_child(parent_id: parent.name, child: child, order: 0)
      dashboard = described_class.new(project_repository: project_repo)

      summary = dashboard.health_summary

      expect(summary[:on_track]).to eq(1)
      expect(summary[:off_track]).to eq(0)
    end
  end

  describe '#state_summary' do
    it 'counts projects by state' do
      projects = [
        build_project(name: 'A', state: :in_progress),
        build_project(name: 'B', state: :in_progress),
        build_project(name: 'C', state: :blocked),
        build_project(name: 'D', state: :on_hold),
        build_project(name: 'E', state: :done)
      ]
      project_repo = FakeProjectRepository.new
      projects.each { |p| project_repo.save(p) }
      dashboard = described_class.new(project_repository: project_repo)

      summary = dashboard.state_summary

      expect(summary[:in_progress]).to eq(2)
      expect(summary[:blocked]).to eq(1)
      expect(summary[:on_hold]).to eq(1)
      expect(summary[:done]).to eq(1)
    end

    it 'excludes archived projects' do
      projects = [
        build_project(name: 'Active', state: :in_progress),
        build_project(name: 'Archived', state: :blocked, archived: true)
      ]
      project_repo = FakeProjectRepository.new
      projects.each { |p| project_repo.save(p) }
      dashboard = described_class.new(project_repository: project_repo)

      summary = dashboard.state_summary

      expect(summary[:in_progress]).to eq(1)
      expect(summary[:blocked]).to eq(0)
    end
  end

  describe '#total_active_projects' do
    it 'counts non-archived root projects' do
      projects = [
        build_project(name: 'A'),
        build_project(name: 'B'),
        build_project(name: 'Archived', archived: true)
      ]
      project_repo = FakeProjectRepository.new
      projects.each { |p| project_repo.save(p) }
      dashboard = described_class.new(project_repository: project_repo)

      expect(dashboard.total_active_projects).to eq(2)
    end
  end

  describe '#attention_required' do
    it 'returns off-track projects' do
      projects = [
        build_project(name: 'Fine', health: :on_track, state: :in_progress),
        build_project(name: 'Problem', health: :off_track, state: :in_progress)
      ]
      project_repo = FakeProjectRepository.new
      projects.each { |p| project_repo.save(p) }
      dashboard = described_class.new(project_repository: project_repo)

      attention = dashboard.attention_required

      expect(attention.map(&:name)).to eq(['Problem'])
    end

    it 'returns blocked projects' do
      projects = [
        build_project(name: 'Fine', health: :on_track, state: :in_progress),
        build_project(name: 'Stuck', health: :on_track, state: :blocked)
      ]
      project_repo = FakeProjectRepository.new
      projects.each { |p| project_repo.save(p) }
      dashboard = described_class.new(project_repository: project_repo)

      attention = dashboard.attention_required

      expect(attention.map(&:name)).to eq(['Stuck'])
    end

    it 'returns at-risk projects' do
      projects = [
        build_project(name: 'Fine', health: :on_track, state: :in_progress),
        build_project(name: 'Risky', health: :at_risk, state: :in_progress)
      ]
      project_repo = FakeProjectRepository.new
      projects.each { |p| project_repo.save(p) }
      dashboard = described_class.new(project_repository: project_repo)

      attention = dashboard.attention_required

      expect(attention.map(&:name)).to eq(['Risky'])
    end

    it 'excludes archived, done, and on_hold projects' do
      projects = [
        build_project(name: 'Archived', health: :off_track, archived: true),
        build_project(name: 'Done', health: :off_track, state: :done),
        build_project(name: 'OnHold', health: :off_track, state: :on_hold)
      ]
      project_repo = FakeProjectRepository.new
      projects.each { |p| project_repo.save(p) }
      dashboard = described_class.new(project_repository: project_repo)

      attention = dashboard.attention_required

      expect(attention).to be_empty
    end

    it 'sorts by health severity then name' do
      projects = [
        build_project(name: 'B Risk', health: :at_risk, state: :in_progress),
        build_project(name: 'A Off', health: :off_track, state: :in_progress),
        build_project(name: 'Z Off', health: :off_track, state: :in_progress)
      ]
      project_repo = FakeProjectRepository.new
      projects.each { |p| project_repo.save(p) }
      dashboard = described_class.new(project_repository: project_repo)

      attention = dashboard.attention_required

      expect(attention.map(&:name)).to eq(['A Off', 'Z Off', 'B Risk'])
    end
  end

  describe '#attention_required_initiatives' do
    def build_initiative(name:, state: :in_progress, health: :on_track, archived: false)
      projects = if health == :on_track
                   [build_project(name: "#{name}-project", health: :on_track)]
                 elsif health == :at_risk
                   [build_project(name: "#{name}-project", health: :at_risk)]
                 elsif health == :off_track
                   [build_project(name: "#{name}-project", health: :off_track)]
                 else
                   []
                 end

      Initiative.new(
        name: name,
        current_state: state,
        archived: archived,
        related_projects_loader: ->(_i) { projects }
      )
    end

    it 'returns off-track initiatives' do
      project_repo = FakeProjectRepository.new
      initiative_repo = FakeInitiativeRepository.new
      initiative_repo.save(build_initiative(name: 'Fine', health: :on_track))
      initiative_repo.save(build_initiative(name: 'Problem', health: :off_track))
      dashboard = described_class.new(project_repository: project_repo, initiative_repository: initiative_repo)

      attention = dashboard.attention_required_initiatives

      expect(attention.map(&:name)).to eq(['Problem'])
    end

    it 'returns at-risk initiatives' do
      project_repo = FakeProjectRepository.new
      initiative_repo = FakeInitiativeRepository.new
      initiative_repo.save(build_initiative(name: 'Fine', health: :on_track))
      initiative_repo.save(build_initiative(name: 'Risky', health: :at_risk))
      dashboard = described_class.new(project_repository: project_repo, initiative_repository: initiative_repo)

      attention = dashboard.attention_required_initiatives

      expect(attention.map(&:name)).to eq(['Risky'])
    end

    it 'returns blocked initiatives' do
      project_repo = FakeProjectRepository.new
      initiative_repo = FakeInitiativeRepository.new
      initiative_repo.save(build_initiative(name: 'Fine', health: :on_track))
      initiative_repo.save(build_initiative(name: 'Stuck', health: :on_track, state: :blocked))
      dashboard = described_class.new(project_repository: project_repo, initiative_repository: initiative_repo)

      attention = dashboard.attention_required_initiatives

      expect(attention.map(&:name)).to eq(['Stuck'])
    end

    it 'excludes archived and done initiatives' do
      project_repo = FakeProjectRepository.new
      initiative_repo = FakeInitiativeRepository.new
      initiative_repo.save(build_initiative(name: 'Archived', health: :off_track, archived: true))
      initiative_repo.save(build_initiative(name: 'Done', health: :off_track, state: :done))
      dashboard = described_class.new(project_repository: project_repo, initiative_repository: initiative_repo)

      attention = dashboard.attention_required_initiatives

      expect(attention).to be_empty
    end

    it 'sorts by health severity then name' do
      project_repo = FakeProjectRepository.new
      initiative_repo = FakeInitiativeRepository.new
      initiative_repo.save(build_initiative(name: 'B Risk', health: :at_risk))
      initiative_repo.save(build_initiative(name: 'A Off', health: :off_track))
      initiative_repo.save(build_initiative(name: 'Z Off', health: :off_track))
      dashboard = described_class.new(project_repository: project_repo, initiative_repository: initiative_repo)

      attention = dashboard.attention_required_initiatives

      expect(attention.map(&:name)).to eq(['A Off', 'Z Off', 'B Risk'])
    end

    it 'returns empty array when initiative_repository is nil' do
      project_repo = FakeProjectRepository.new
      dashboard = described_class.new(project_repository: project_repo, initiative_repository: nil)

      attention = dashboard.attention_required_initiatives

      expect(attention).to eq([])
    end
  end

  describe '#attention_required_teams' do
    def build_team(name:, health: :on_track, archived: false)
      projects = if health == :on_track
                   [build_project(name: "#{name}-project", health: :on_track)]
                 elsif health == :at_risk
                   [build_project(name: "#{name}-project", health: :at_risk)]
                 elsif health == :off_track
                   [build_project(name: "#{name}-project", health: :off_track)]
                 else
                   []
                 end

      Team.new(
        name: name,
        archived: archived,
        owned_projects_loader: ->(_t) { projects }
      )
    end

    it 'returns off-track teams' do
      project_repo = FakeProjectRepository.new
      team_repo = FakeTeamRepository.new
      team_repo.save(build_team(name: 'Fine', health: :on_track))
      team_repo.save(build_team(name: 'Problem', health: :off_track))
      dashboard = described_class.new(project_repository: project_repo, team_repository: team_repo)

      attention = dashboard.attention_required_teams

      expect(attention.map(&:name)).to eq(['Problem'])
    end

    it 'returns at-risk teams' do
      project_repo = FakeProjectRepository.new
      team_repo = FakeTeamRepository.new
      team_repo.save(build_team(name: 'Fine', health: :on_track))
      team_repo.save(build_team(name: 'Risky', health: :at_risk))
      dashboard = described_class.new(project_repository: project_repo, team_repository: team_repo)

      attention = dashboard.attention_required_teams

      expect(attention.map(&:name)).to eq(['Risky'])
    end

    it 'excludes archived teams' do
      project_repo = FakeProjectRepository.new
      team_repo = FakeTeamRepository.new
      team_repo.save(build_team(name: 'Archived', health: :off_track, archived: true))
      dashboard = described_class.new(project_repository: project_repo, team_repository: team_repo)

      attention = dashboard.attention_required_teams

      expect(attention).to be_empty
    end

    it 'sorts by health severity then name' do
      project_repo = FakeProjectRepository.new
      team_repo = FakeTeamRepository.new
      team_repo.save(build_team(name: 'B Risk', health: :at_risk))
      team_repo.save(build_team(name: 'A Off', health: :off_track))
      team_repo.save(build_team(name: 'Z Off', health: :off_track))
      dashboard = described_class.new(project_repository: project_repo, team_repository: team_repo)

      attention = dashboard.attention_required_teams

      expect(attention.map(&:name)).to eq(['A Off', 'Z Off', 'B Risk'])
    end

    it 'returns empty array when team_repository is nil' do
      project_repo = FakeProjectRepository.new
      dashboard = described_class.new(project_repository: project_repo, team_repository: nil)

      attention = dashboard.attention_required_teams

      expect(attention).to eq([])
    end
  end

  describe '#recent_health_updates' do
    it 'returns recent health updates across all projects' do
      project_repo = FakeProjectRepository.new
      project = build_project(name: 'Alpha')
      project_repo.save(project)

      health_repo = FakeHealthUpdateRepository.new
      update1 = HealthUpdate.new(project_id: project.name, date: Date.new(2025, 1, 10), health: :on_track, description: 'Looking good')
      update2 = HealthUpdate.new(project_id: project.name, date: Date.new(2025, 1, 15), health: :at_risk, description: 'Some issues')
      health_repo.save(update1)
      health_repo.save(update2)

      dashboard = described_class.new(project_repository: project_repo, health_update_repository: health_repo)

      updates = dashboard.recent_health_updates(limit: 5)

      expect(updates.length).to eq(2)
      expect(updates.first.date).to eq(Date.new(2025, 1, 15))
      expect(updates.first.description).to eq('Some issues')
    end

    it 'limits results' do
      project_repo = FakeProjectRepository.new
      project = build_project(name: 'Alpha')
      project_repo.save(project)

      health_repo = FakeHealthUpdateRepository.new
      5.times do |i|
        update = HealthUpdate.new(project_id: project.name, date: Date.new(2025, 1, i + 1), health: :on_track)
        health_repo.save(update)
      end

      dashboard = described_class.new(project_repository: project_repo, health_update_repository: health_repo)

      updates = dashboard.recent_health_updates(limit: 3)

      expect(updates.length).to eq(3)
    end

    it 'includes project name with each update' do
      project_repo = FakeProjectRepository.new
      project = build_project(name: 'Alpha')
      project_repo.save(project)

      health_repo = FakeHealthUpdateRepository.new
      update = HealthUpdate.new(project_id: project.name, date: Date.new(2025, 1, 10), health: :on_track)
      health_repo.save(update)

      dashboard = described_class.new(project_repository: project_repo, health_update_repository: health_repo)

      updates = dashboard.recent_health_updates(limit: 5)

      expect(updates.first.project_name).to eq('Alpha')
    end

    it 'returns Unknown when project is not found' do
      project_repo = FakeProjectRepository.new

      health_repo = FakeHealthUpdateRepository.new
      update = HealthUpdate.new(project_id: 'nonexistent', date: Date.new(2025, 1, 10), health: :on_track)
      health_repo.save(update)

      dashboard = described_class.new(project_repository: project_repo, health_update_repository: health_repo)

      updates = dashboard.recent_health_updates(limit: 5)

      expect(updates.first.project_name).to eq('Unknown')
    end

    it 'returns empty array when health_update_repository is nil' do
      project_repo = FakeProjectRepository.new
      dashboard = described_class.new(project_repository: project_repo, health_update_repository: nil)

      updates = dashboard.recent_health_updates(limit: 5)

      expect(updates).to eq([])
    end
  end

  describe '#stale_projects' do
    it 'returns projects with no health update in the given days' do
      project_repo = FakeProjectRepository.new
      fresh_project = build_project(name: 'Fresh')
      stale_project = build_project(name: 'Stale')
      project_repo.save(fresh_project)
      project_repo.save(stale_project)

      health_repo = FakeHealthUpdateRepository.new
      health_repo.save(HealthUpdate.new(project_id: fresh_project.name, date: Date.today - 5, health: :on_track))
      health_repo.save(HealthUpdate.new(project_id: stale_project.name, date: Date.today - 20, health: :on_track))

      dashboard = described_class.new(project_repository: project_repo, health_update_repository: health_repo)

      stale = dashboard.stale_projects(days: 14)

      expect(stale.map(&:name)).to eq(['Stale'])
    end

    it 'excludes projects with no health updates' do
      project_repo = FakeProjectRepository.new
      project = build_project(name: 'NoUpdates')
      project_repo.save(project)

      health_repo = FakeHealthUpdateRepository.new
      dashboard = described_class.new(project_repository: project_repo, health_update_repository: health_repo)

      stale = dashboard.stale_projects(days: 14)

      expect(stale).to be_empty
    end

    it 'excludes archived, done, and on_hold projects' do
      project_repo = FakeProjectRepository.new
      archived = build_project(name: 'Archived', archived: true)
      done = build_project(name: 'Done', state: :done)
      on_hold = build_project(name: 'OnHold', state: :on_hold)
      project_repo.save(archived)
      project_repo.save(done)
      project_repo.save(on_hold)

      health_repo = FakeHealthUpdateRepository.new
      dashboard = described_class.new(project_repository: project_repo, health_update_repository: health_repo)

      stale = dashboard.stale_projects(days: 14)

      expect(stale).to be_empty
    end

    it 'excludes new and todo projects even with stale health updates' do
      project_repo = FakeProjectRepository.new
      new_project = build_project(name: 'NewProject', state: :new)
      todo_project = build_project(name: 'TodoProject', state: :todo)
      project_repo.save(new_project)
      project_repo.save(todo_project)

      health_repo = FakeHealthUpdateRepository.new
      health_repo.save(HealthUpdate.new(project_id: new_project.name, date: Date.today - 20, health: :on_track))
      health_repo.save(HealthUpdate.new(project_id: todo_project.name, date: Date.today - 20, health: :on_track))

      dashboard = described_class.new(project_repository: project_repo, health_update_repository: health_repo)

      stale = dashboard.stale_projects(days: 14)

      expect(stale).to be_empty
    end

    it 'uses project id when available' do
      # Create a project with an explicit id
      health_update = HealthUpdate.new(project_id: 'test-id', date: Date.today, health: :on_track)
      attrs = ProjectAttributes.new(id: 'test-id', name: 'WithId', current_state: :in_progress)
      loaders = ProjectLoaders.new(health_updates: ->(_p) { [health_update] })
      project = Project.new(attributes: attrs, loaders: loaders)

      project_repo = FakeProjectRepository.new
      project_repo.save(project)

      health_repo = FakeHealthUpdateRepository.new
      health_repo.save(HealthUpdate.new(project_id: 'test-id', date: Date.today - 5, health: :on_track))

      dashboard = described_class.new(project_repository: project_repo, health_update_repository: health_repo)

      stale = dashboard.stale_projects(days: 14)

      expect(stale).to be_empty
    end

    it 'falls back to project name when id is nil' do
      project_repo = FakeProjectRepository.new
      project = build_project(name: 'NoIdProject')
      project_repo.save(project)

      health_repo = FakeHealthUpdateRepository.new
      # Use the project name as the project_id since it has no id
      health_repo.save(HealthUpdate.new(project_id: 'NoIdProject', date: Date.today - 20, health: :on_track))

      dashboard = described_class.new(project_repository: project_repo, health_update_repository: health_repo)

      stale = dashboard.stale_projects(days: 14)

      expect(stale.map(&:name)).to eq(['NoIdProject'])
    end

    it 'returns empty when health_update_repository is nil' do
      project_repo = FakeProjectRepository.new
      project = build_project(name: 'AnyProject')
      project_repo.save(project)

      dashboard = described_class.new(project_repository: project_repo, health_update_repository: nil)

      stale = dashboard.stale_projects(days: 14)

      expect(stale).to be_empty
    end
  end

  describe '#stale_projects_between' do
    it 'returns projects with updates between min and max days ago' do
      project_repo = FakeProjectRepository.new
      project_7_days = build_project(name: 'SevenDays')
      project_14_days = build_project(name: 'FourteenDays')
      project_3_days = build_project(name: 'ThreeDays')
      project_repo.save(project_7_days)
      project_repo.save(project_14_days)
      project_repo.save(project_3_days)

      health_repo = FakeHealthUpdateRepository.new
      health_repo.save(HealthUpdate.new(project_id: project_7_days.name, date: Date.today - 10, health: :on_track))
      health_repo.save(HealthUpdate.new(project_id: project_14_days.name, date: Date.today - 20, health: :on_track))
      health_repo.save(HealthUpdate.new(project_id: project_3_days.name, date: Date.today - 3, health: :on_track))

      dashboard = described_class.new(project_repository: project_repo, health_update_repository: health_repo)

      stale = dashboard.stale_projects_between(min_days: 7, max_days: 14)

      expect(stale.map(&:name)).to eq(['SevenDays'])
    end

    it 'excludes projects with no health updates' do
      project_repo = FakeProjectRepository.new
      project = build_project(name: 'NoUpdates')
      project_repo.save(project)

      health_repo = FakeHealthUpdateRepository.new
      dashboard = described_class.new(project_repository: project_repo, health_update_repository: health_repo)

      stale = dashboard.stale_projects_between(min_days: 7, max_days: 14)

      expect(stale).to be_empty
    end

    it 'excludes new and todo projects even with stale health updates' do
      project_repo = FakeProjectRepository.new
      new_project = build_project(name: 'NewProject', state: :new)
      todo_project = build_project(name: 'TodoProject', state: :todo)
      project_repo.save(new_project)
      project_repo.save(todo_project)

      health_repo = FakeHealthUpdateRepository.new
      health_repo.save(HealthUpdate.new(project_id: new_project.name, date: Date.today - 10, health: :on_track))
      health_repo.save(HealthUpdate.new(project_id: todo_project.name, date: Date.today - 10, health: :on_track))

      dashboard = described_class.new(project_repository: project_repo, health_update_repository: health_repo)

      stale = dashboard.stale_projects_between(min_days: 7, max_days: 14)

      expect(stale).to be_empty
    end

    it 'uses project id when available' do
      health_update = HealthUpdate.new(project_id: 'test-id', date: Date.today - 10, health: :on_track)
      attrs = ProjectAttributes.new(id: 'test-id', name: 'WithId', current_state: :in_progress)
      loaders = ProjectLoaders.new(health_updates: ->(_p) { [health_update] })
      project = Project.new(attributes: attrs, loaders: loaders)

      project_repo = FakeProjectRepository.new
      project_repo.save(project)

      health_repo = FakeHealthUpdateRepository.new
      health_repo.save(health_update)

      dashboard = described_class.new(project_repository: project_repo, health_update_repository: health_repo)

      stale = dashboard.stale_projects_between(min_days: 7, max_days: 14)

      expect(stale.map(&:name)).to eq(['WithId'])
    end

    it 'returns empty when health_update_repository is nil' do
      project_repo = FakeProjectRepository.new
      project = build_project(name: 'AnyProject')
      project_repo.save(project)

      dashboard = described_class.new(project_repository: project_repo, health_update_repository: nil)

      stale = dashboard.stale_projects_between(min_days: 7, max_days: 14)

      expect(stale).to be_empty
    end
  end

  describe '#never_updated_projects' do
    it 'returns projects with not_available health' do
      project_repo = FakeProjectRepository.new

      # Create a project with not_available health (loader returns empty array)
      attrs = ProjectAttributes.new(name: 'NotAvailable', current_state: :in_progress)
      loaders = ProjectLoaders.new(health_updates: ->(_p) { [] })
      not_available_project = Project.new(attributes: attrs, loaders: loaders)

      project_repo.save(not_available_project)

      dashboard = described_class.new(project_repository: project_repo)

      result = dashboard.never_updated_projects

      expect(result.map(&:name)).to eq(['NotAvailable'])
    end

    it 'excludes projects that derive health from children' do
      project_repo = FakeProjectRepository.new
      # Project with on_track health (has health updates in loader)
      project = build_project(name: 'DerivedHealth', health: :on_track)
      project_repo.save(project)

      dashboard = described_class.new(project_repository: project_repo)

      result = dashboard.never_updated_projects

      expect(result).to be_empty
    end

    it 'returns empty when all projects have a health status' do
      project_repo = FakeProjectRepository.new
      project = build_project(name: 'Updated', health: :on_track)
      project_repo.save(project)

      dashboard = described_class.new(project_repository: project_repo)

      result = dashboard.never_updated_projects

      expect(result).to be_empty
    end
  end

  describe '#on_hold_projects' do
    it 'returns projects with on_hold state' do
      project_repo = FakeProjectRepository.new
      on_hold = build_project(name: 'OnHold', state: :on_hold)
      in_progress = build_project(name: 'InProgress', state: :in_progress)
      project_repo.save(on_hold)
      project_repo.save(in_progress)

      dashboard = described_class.new(project_repository: project_repo)

      result = dashboard.on_hold_projects

      expect(result.map(&:name)).to eq(['OnHold'])
    end

    it 'excludes archived projects' do
      project_repo = FakeProjectRepository.new
      on_hold_archived = build_project(name: 'OnHoldArchived', state: :on_hold, archived: true)
      project_repo.save(on_hold_archived)

      dashboard = described_class.new(project_repository: project_repo)

      result = dashboard.on_hold_projects

      expect(result).to be_empty
    end
  end

  describe '#orphan_projects' do
    it 'returns orphan projects from the repository' do
      project_repo = FakeProjectRepository.new
      orphan = build_project(name: 'Orphan')
      project_repo.save(orphan)

      dashboard = described_class.new(project_repository: project_repo)

      result = dashboard.orphan_projects

      expect(result.map(&:name)).to eq(['Orphan'])
    end

    it 'excludes done projects' do
      project_repo = FakeProjectRepository.new
      done_orphan = build_project(name: 'DoneOrphan', state: :done)
      project_repo.save(done_orphan)

      dashboard = described_class.new(project_repository: project_repo)

      result = dashboard.orphan_projects

      expect(result).to be_empty
    end

    it 'excludes on_hold projects' do
      project_repo = FakeProjectRepository.new
      on_hold_orphan = build_project(name: 'OnHoldOrphan', state: :on_hold)
      project_repo.save(on_hold_orphan)

      dashboard = described_class.new(project_repository: project_repo)

      result = dashboard.orphan_projects

      expect(result).to be_empty
    end
  end

end
