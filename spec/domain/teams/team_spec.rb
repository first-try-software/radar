require 'spec_helper'
require_relative '../../support/domain/team_builder'

RSpec.describe Team do
  include TeamBuilder

  it 'is valid when it has a name' do
    team = build_team(name: 'Platform')

    expect(team.valid?).to be(true)
  end

  it 'is invalid when its name is blank' do
    team = build_team(name: '')

    expect(team.valid?).to be(false)
  end

  it 'returns validation errors when invalid' do
    team = build_team(name: '')

    expect(team.errors).to eq(['name must be present'])
  end

  it 'returns no validation errors when valid' do
    team = build_team(name: 'Platform')

    expect(team.errors).to eq([])
  end

  it 'returns empty owned projects when no loader provided' do
    team = build_team(name: 'Platform')

    expect(team.owned_projects).to eq([])
  end

  it 'lazy loads owned projects via the loader' do
    loader = ->(_team) { [double('Project')] }
    team = build_team(name: 'Platform', owned_projects_loader: loader)

    expect(team.owned_projects.length).to eq(1)
  end

  it 'returns empty subordinate teams when no loader provided' do
    team = build_team(name: 'Platform')

    expect(team.subordinate_teams).to eq([])
  end

  it 'lazy loads subordinate teams via the loader' do
    loader = ->(_team) { [double('Team')] }
    team = build_team(name: 'Platform', subordinate_teams_loader: loader)

    expect(team.subordinate_teams.length).to eq(1)
  end

  describe '#health' do
    it 'returns :not_available when no subordinate teams or owned projects are present' do
      team = build_team(name: 'Platform')

      expect(team.health).to eq(:not_available)
    end

    it 'returns average health of subordinate teams when no owned projects are present' do
      subordinate_teams_loader = ->(_team) { [double('Team', health: :on_track, health_raw_score: 1.0)] }
      team = build_team(name: 'Platform', subordinate_teams_loader:)

      expect(team.health).to eq(:on_track)
    end

    it 'returns average health of owned projects in active states when no subordinate teams are present' do
      project = double('Project', current_state: :in_progress, health: :on_track, archived?: false)
      owned_projects_loader = ->(_team) { [project] }
      team = build_team(name: 'Platform', owned_projects_loader:)

      expect(team.health).to eq(:on_track)
    end

    it 'returns :not_available when when no subordinate teams are present and no owned projects are in an active state' do
      project = double('Project', current_state: :todo, health: :on_track, archived?: false)
      owned_projects_loader = ->(_team) { [project] }
      team = build_team(name: 'Platform', owned_projects_loader:)

      expect(team.health).to eq(:not_available)
    end

    it 'returns average health of subordinate teams and owned projects in active states when both are present' do
      team1 = double('Team1', health: :on_track, health_raw_score: 1.0)
      team2 = double('Team2', health: :on_track, health_raw_score: 1.0)
      project1 = double('Project1', current_state: :in_progress, health: :on_track, archived?: false)
      project2 = double('Project2', current_state: :in_progress, health: :off_track, archived?: false)
      subordinate_teams_loader = ->(_team) { [team1, team2] }
      owned_projects_loader = ->(_project) { [project1, project2] }
      team = build_team(name: 'Platform', subordinate_teams_loader:, owned_projects_loader:)

      expect(team.health).to eq(:on_track)
    end

    it 'returns :not_available when there are no activeowned projects in the hierarchy' do
      project = double('Project', current_state: :todo, health: :on_track, archived?: false)
      owned_projects_loader = ->(_project) { [project] }
      child_team = build_team(name: 'Child', owned_projects_loader:)
      subordinate_teams_loader = ->(_t) { [child_team] }
      parent_team = build_team(name: 'Parent', subordinate_teams_loader:)

      expect(parent_team.health).to eq(:not_available)
    end

    it 'ignores subordinate teams with not_available health' do
      child_team = double('ChildTeam', health: :on_track, health_raw_score: 1.0)
      empty_child_team = double('EmptyChildTeam', health: :not_available, health_raw_score: nil)
      parent_team = build_team(
        name: 'Parent',
        subordinate_teams_loader: ->(_t) { [child_team, empty_child_team] }
      )

      expect(parent_team.health).to eq(:on_track)
    end

    it 'ignores owned projects with not_available health' do
      owned_project = double('OwnedProject', health: :on_track, current_state: :in_progress, archived?: false)
      empty_project = double('EmptyProject', health: :not_available, current_state: :todo, archived?: false)

      parent_team = build_team(
        name: 'Parent',
        owned_projects_loader: ->(_project) { [owned_project, empty_project] }
      )

      expect(parent_team.health).to eq(:on_track)
    end
  end

  describe '#health_raw_score' do
    it 'returns the raw score based on owned projects' do
      project = double('Project', current_state: :in_progress, health: :on_track, archived?: false)
      team = build_team(name: 'Platform', owned_projects_loader: ->(_team) { [project] })

      expect(team.health_raw_score).to eq(1.0)
    end

    it 'returns nil when no owned projects are in an active state' do
      project = double('Project', current_state: :todo, health: :on_track, archived?: false)
      team = build_team(name: 'Platform', owned_projects_loader: ->(_team) { [project] })

      expect(team.health_raw_score).to be_nil
    end
  end

  describe '#parent_team' do
    it 'returns nil when no loader provided' do
      team = build_team(name: 'Platform')

      expect(team.parent_team).to be_nil
    end

    it 'lazy loads parent team via the loader' do
      parent = build_team(name: 'Parent')
      loader = ->(_team) { parent }
      team = build_team(name: 'Child', parent_team_loader: loader)

      expect(team.parent_team).to eq(parent)
    end
  end

  describe '#effective_contact' do
    it 'returns own point_of_contact when present' do
      team = build_team(name: 'Platform', point_of_contact: 'Alice')

      expect(team.effective_contact).to eq('Alice')
    end

    it 'returns parent point_of_contact when own is blank' do
      parent = build_team(name: 'Parent', point_of_contact: 'Bob')
      team = build_team(name: 'Child', point_of_contact: '', parent_team_loader: ->(_t) { parent })

      expect(team.effective_contact).to eq('Bob')
    end

    it 'traverses multiple levels to find contact' do
      grandparent = build_team(name: 'Grandparent', point_of_contact: 'Carol')
      parent = build_team(name: 'Parent', point_of_contact: '', parent_team_loader: ->(_t) { grandparent })
      team = build_team(name: 'Child', point_of_contact: '', parent_team_loader: ->(_t) { parent })

      expect(team.effective_contact).to eq('Carol')
    end

    it 'returns nil when no contact found in hierarchy' do
      parent = build_team(name: 'Parent', point_of_contact: '')
      team = build_team(name: 'Child', point_of_contact: '', parent_team_loader: ->(_t) { parent })

      expect(team.effective_contact).to be_nil
    end
  end
end
