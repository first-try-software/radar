require 'spec_helper'
require 'domain/teams/team'

RSpec.describe Team do
  it 'returns its name' do
    team = described_class.new(name: 'Platform')

    expect(team.name).to eq('Platform')
  end

  it 'returns its mission' do
    team = described_class.new(name: 'Platform', mission: 'Enable delivery velocity')

    expect(team.mission).to eq('Enable delivery velocity')
  end

  it 'returns its vision' do
    team = described_class.new(name: 'Platform', vision: 'Create clarity')

    expect(team.vision).to eq('Create clarity')
  end

  it 'defaults vision to an empty string' do
    team = described_class.new(name: 'Platform')

    expect(team.vision).to eq('')
  end

  it 'defaults mission to an empty string' do
    team = described_class.new(name: 'Platform')

    expect(team.mission).to eq('')
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
    it 'returns a rollup of leaf projects from owned projects' do
      leaf_project = double('Project', current_state: :in_progress, health: :on_track)
      owned_project = double('Project', leaf_descendants: [leaf_project])
      team = described_class.new(name: 'Platform', owned_projects_loader: ->(_team) { [owned_project] })

      expect(team.health).to eq(:on_track)
    end

    it 'returns :not_available when no leaf projects are in a working state' do
      leaf_project = double('Project', current_state: :todo, health: :on_track)
      owned_project = double('Project', leaf_descendants: [leaf_project])
      team = described_class.new(name: 'Platform', owned_projects_loader: ->(_team) { [owned_project] })

      expect(team.health).to eq(:not_available)
    end

    it 'includes leaf projects from subordinate teams' do
      parent_leaf = double('Project', current_state: :in_progress, health: :on_track)
      parent_project = double('Project', leaf_descendants: [parent_leaf])
      child_leaf = double('Project', current_state: :blocked, health: :off_track)
      child_project = double('Project', leaf_descendants: [child_leaf])
      child_team = described_class.new(name: 'Child', owned_projects_loader: ->(_t) { [child_project] })
      parent_team = described_class.new(
        name: 'Parent',
        owned_projects_loader: ->(_t) { [parent_project] },
        subordinate_teams_loader: ->(_t) { [child_team] }
      )

      expect(parent_team.health).to eq(:at_risk)
    end

    it 'recursively includes leaf projects from nested subordinate teams' do
      grandchild_leaf = double('Project', current_state: :in_progress, health: :off_track)
      grandchild_project = double('Project', leaf_descendants: [grandchild_leaf])
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
  end

  describe '#health_raw_score' do
    it 'returns the raw score from HealthRollup' do
      leaf_project = double('Project', current_state: :in_progress, health: :on_track)
      owned_project = double('Project', leaf_descendants: [leaf_project])
      team = described_class.new(name: 'Platform', owned_projects_loader: ->(_team) { [owned_project] })

      expect(team.health_raw_score).to eq(1.0)
    end

    it 'returns nil when no leaf projects are in a working state' do
      leaf_project = double('Project', current_state: :todo, health: :on_track)
      owned_project = double('Project', leaf_descendants: [leaf_project])
      team = described_class.new(name: 'Platform', owned_projects_loader: ->(_team) { [owned_project] })

      expect(team.health_raw_score).to be_nil
    end
  end
end
