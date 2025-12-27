require 'spec_helper'
require 'domain/teams/team'

RSpec.describe Team do
  it 'returns its name' do
    team = described_class.new(name: 'Platform')

    expect(team.name).to eq('Platform')
  end

  it 'returns its description' do
    team = described_class.new(name: 'Platform', description: 'Enable delivery velocity')

    expect(team.description).to eq('Enable delivery velocity')
  end

  it 'defaults description to an empty string' do
    team = described_class.new(name: 'Platform')

    expect(team.description).to eq('')
  end

  it 'returns its point of contact' do
    team = described_class.new(name: 'Platform', point_of_contact: 'Jordan')

    expect(team.point_of_contact).to eq('Jordan')
  end

  it 'defaults point_of_contact to an empty string' do
    team = described_class.new(name: 'Platform')

    expect(team.point_of_contact).to eq('')
  end

  it 'records whether it has been archived' do
    team = described_class.new(name: 'Platform', archived: true)

    expect(team).to be_archived
  end

  it 'defaults archived to false' do
    team = described_class.new(name: 'Platform')

    expect(team).not_to be_archived
  end

  it 'is valid when it has a name' do
    team = described_class.new(name: 'Platform')

    expect(team.valid?).to be(true)
  end

  it 'is invalid when its name is blank' do
    team = described_class.new(name: '')

    expect(team.valid?).to be(false)
  end

  it 'returns validation errors when invalid' do
    team = described_class.new(name: '')

    expect(team.errors).to eq(['name must be present'])
  end

  it 'returns no validation errors when valid' do
    team = described_class.new(name: 'Platform')

    expect(team.errors).to eq([])
  end

  it 'returns empty owned projects when no loader provided' do
    team = described_class.new(name: 'Platform')

    expect(team.owned_projects).to eq([])
  end

  it 'lazy loads owned projects via the loader' do
    loader = ->(_team) { [double('Project')] }
    team = described_class.new(name: 'Platform', owned_projects_loader: loader)

    expect(team.owned_projects.length).to eq(1)
  end

  it 'returns empty subordinate teams when no loader provided' do
    team = described_class.new(name: 'Platform')

    expect(team.subordinate_teams).to eq([])
  end

  it 'lazy loads subordinate teams via the loader' do
    loader = ->(_team) { [double('Team')] }
    team = described_class.new(name: 'Platform', subordinate_teams_loader: loader)

    expect(team.subordinate_teams.length).to eq(1)
  end

  describe '#health' do
    it 'returns health based on owned projects in working states' do
      project = double('Project', current_state: :in_progress, health: :on_track)
      team = described_class.new(name: 'Platform', owned_projects_loader: ->(_team) { [project] })

      expect(team.health).to eq(:on_track)
    end

    it 'returns :not_available when no owned projects are in a working state' do
      project = double('Project', current_state: :todo, health: :on_track)
      team = described_class.new(name: 'Platform', owned_projects_loader: ->(_team) { [project] })

      expect(team.health).to eq(:not_available)
    end

    it 'weights each owned project equally regardless of decomposition' do
      # A parent project with many children gets same weight as a leaf project
      leaf_project = double('Project', current_state: :in_progress, health: :off_track)
      parent_project = double('Project', current_state: :in_progress, health: :on_track)
      team = described_class.new(
        name: 'Platform',
        owned_projects_loader: ->(_team) { [leaf_project, parent_project] }
      )

      # off_track (-1) + on_track (1) = 0 average -> at_risk
      expect(team.health).to eq(:at_risk)
    end

    it 'treats local projects as a group with equal weight to each child team' do
      # Parent team owns one project, child team has its own rolled-up health
      parent_project = double('Project', current_state: :in_progress, health: :on_track)
      child_project = double('Project', current_state: :blocked, health: :off_track)
      child_team = described_class.new(name: 'Child', owned_projects_loader: ->(_t) { [child_project] })
      parent_team = described_class.new(
        name: 'Parent',
        owned_projects_loader: ->(_t) { [parent_project] },
        subordinate_teams_loader: ->(_t) { [child_team] }
      )

      # Local projects (1 vote: on_track=1) + child team (1 vote: off_track=-1) = average 0 -> at_risk
      expect(parent_team.health).to eq(:at_risk)
    end

    it 'gives local projects as a group equal weight regardless of count' do
      # Many local projects get aggregated into one vote, equal to one child team vote
      local_project1 = double('Project', current_state: :in_progress, health: :on_track)
      local_project2 = double('Project', current_state: :in_progress, health: :on_track)
      local_project3 = double('Project', current_state: :in_progress, health: :on_track)
      child_project = double('Project', current_state: :in_progress, health: :off_track)
      child_team = described_class.new(name: 'Child', owned_projects_loader: ->(_t) { [child_project] })
      parent_team = described_class.new(
        name: 'Parent',
        owned_projects_loader: ->(_t) { [local_project1, local_project2, local_project3] },
        subordinate_teams_loader: ->(_t) { [child_team] }
      )

      # Local projects aggregate: (1+1+1)/3 = 1 (one vote)
      # Child team: off_track = -1 (one vote)
      # Average: (1 + -1) / 2 = 0 -> at_risk
      expect(parent_team.health).to eq(:at_risk)
    end

    it 'recursively includes health from nested subordinate teams' do
      grandchild_project = double('Project', current_state: :in_progress, health: :off_track)
      grandchild_team = described_class.new(name: 'Grandchild', owned_projects_loader: ->(_t) { [grandchild_project] })
      child_team = described_class.new(name: 'Child', subordinate_teams_loader: ->(_t) { [grandchild_team] })
      parent_team = described_class.new(name: 'Parent', subordinate_teams_loader: ->(_t) { [child_team] })

      expect(parent_team.health).to eq(:off_track)
    end

    it 'returns :not_available when there are no owned projects in the hierarchy' do
      child_team = described_class.new(name: 'Child')
      parent_team = described_class.new(name: 'Parent', subordinate_teams_loader: ->(_t) { [child_team] })

      expect(parent_team.health).to eq(:not_available)
    end

    it 'ignores subordinate teams with not_available health' do
      project = double('Project', current_state: :in_progress, health: :on_track)
      empty_child_team = described_class.new(name: 'EmptyChild')
      parent_team = described_class.new(
        name: 'Parent',
        owned_projects_loader: ->(_t) { [project] },
        subordinate_teams_loader: ->(_t) { [empty_child_team] }
      )

      # Only parent's project counts since child has no health data
      expect(parent_team.health).to eq(:on_track)
    end
  end

  describe '#health_raw_score' do
    it 'returns the raw score based on owned projects' do
      project = double('Project', current_state: :in_progress, health: :on_track)
      team = described_class.new(name: 'Platform', owned_projects_loader: ->(_team) { [project] })

      expect(team.health_raw_score).to eq(1.0)
    end

    it 'returns nil when no owned projects are in a working state' do
      project = double('Project', current_state: :todo, health: :on_track)
      team = described_class.new(name: 'Platform', owned_projects_loader: ->(_team) { [project] })

      expect(team.health_raw_score).to be_nil
    end
  end

  describe '#parent_team' do
    it 'returns nil when no loader provided' do
      team = described_class.new(name: 'Platform')

      expect(team.parent_team).to be_nil
    end

    it 'lazy loads parent team via the loader' do
      parent = described_class.new(name: 'Parent')
      loader = ->(_team) { parent }
      team = described_class.new(name: 'Child', parent_team_loader: loader)

      expect(team.parent_team).to eq(parent)
    end
  end

  describe '#effective_contact' do
    it 'returns own point_of_contact when present' do
      team = described_class.new(name: 'Platform', point_of_contact: 'Alice')

      expect(team.effective_contact).to eq('Alice')
    end

    it 'returns parent point_of_contact when own is blank' do
      parent = described_class.new(name: 'Parent', point_of_contact: 'Bob')
      team = described_class.new(name: 'Child', point_of_contact: '', parent_team_loader: ->(_t) { parent })

      expect(team.effective_contact).to eq('Bob')
    end

    it 'traverses multiple levels to find contact' do
      grandparent = described_class.new(name: 'Grandparent', point_of_contact: 'Carol')
      parent = described_class.new(name: 'Parent', point_of_contact: '', parent_team_loader: ->(_t) { grandparent })
      team = described_class.new(name: 'Child', point_of_contact: '', parent_team_loader: ->(_t) { parent })

      expect(team.effective_contact).to eq('Carol')
    end

    it 'returns nil when no contact found in hierarchy' do
      parent = described_class.new(name: 'Parent', point_of_contact: '')
      team = described_class.new(name: 'Child', point_of_contact: '', parent_team_loader: ->(_t) { parent })

      expect(team.effective_contact).to be_nil
    end
  end
end
