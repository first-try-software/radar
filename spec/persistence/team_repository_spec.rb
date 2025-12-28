require 'rails_helper'
require 'domain/teams/team'
require 'domain/projects/project'
require 'domain/projects/project_attributes'
require Rails.root.join('app/persistence/team_repository')
require Rails.root.join('app/persistence/project_repository')
require Rails.root.join('app/persistence/health_update_repository')

RSpec.describe TeamRepository do
  let(:health_repository) { HealthUpdateRepository.new }
  let(:project_repository) { ProjectRepository.new(health_update_repository: health_repository) }
  subject(:repository) { described_class.new(project_repository: project_repository) }

  def build_team(name)
    Team.new(name: name)
  end

  def build_project(name)
    attrs = ProjectAttributes.new(name: name)
    Project.new(attributes: attrs)
  end

  describe '#find' do
    it 'finds teams by id' do
      record = TeamRecord.create!(name: 'Platform Team')

      result = repository.find(record.id)

      expect(result.name).to eq('Platform Team')
    end

    it 'returns nil when not found' do
      result = repository.find(999)

      expect(result).to be_nil
    end

    it 'maps archived flag correctly' do
      record = TeamRecord.create!(name: 'Archived', archived: true)

      result = repository.find(record.id)

      expect(result.archived?).to be(true)
    end

    it 'maps description correctly' do
      record = TeamRecord.create!(name: 'Team', description: 'Build stuff')

      result = repository.find(record.id)

      expect(result.description).to eq('Build stuff')
    end
  end

  describe '#save' do
    it 'saves new teams' do
      team = build_team('Platform Team')

      repository.save(team)

      expect(repository.exists_with_name?('Platform Team')).to be(true)
    end

    it 'saves description and point_of_contact' do
      team = Team.new(name: 'Team', description: 'Description', point_of_contact: 'POC')

      repository.save(team)

      record = TeamRecord.find_by(name: 'Team')
      expect(record.description).to eq('Description')
      expect(record.point_of_contact).to eq('POC')
    end
  end

  describe '#update' do
    it 'updates teams by id' do
      record = TeamRecord.create!(name: 'Platform Team')
      updated = Team.new(name: 'Infra Team', description: 'Updated description')

      repository.update(id: record.id, team: updated)

      result = repository.find(record.id)
      expect(result.name).to eq('Infra Team')
      expect(result.description).to eq('Updated description')
    end

    it 'returns nil when team not found' do
      team = build_team('NonExistent')

      result = repository.update(id: 999, team: team)

      expect(result).to be_nil
    end
  end

  describe '#exists_with_name?' do
    it 'checks for existing names' do
      TeamRecord.create!(name: 'Platform Team')

      expect(repository.exists_with_name?('Platform Team')).to be(true)
      expect(repository.exists_with_name?('Other')).to be(false)
    end
  end

  describe 'owned project relationships' do
    it 'links owned projects and tracks order' do
      team = TeamRecord.create!(name: 'Platform Team')
      project = build_project('Feature A')
      project_repository.save(project)

      repository.link_owned_project(team_id: team.id, project: project, order: 0)

      relationships = repository.owned_projects_for(team_id: team.id)
      expect(relationships.first[:project].name).to eq('Feature A')
      expect(relationships.first[:order]).to eq(0)
    end

    it 'calculates next order for owned projects' do
      team = TeamRecord.create!(name: 'Platform Team')
      project_one = build_project('Feature A')
      project_two = build_project('Feature B')
      project_repository.save(project_one)
      project_repository.save(project_two)

      expect(repository.next_owned_project_order(team_id: team.id)).to eq(0)

      repository.link_owned_project(team_id: team.id, project: project_one, order: 0)
      expect(repository.next_owned_project_order(team_id: team.id)).to eq(1)

      repository.link_owned_project(team_id: team.id, project: project_two, order: 1)
      expect(repository.next_owned_project_order(team_id: team.id)).to eq(2)
    end

    it 'lazy loads owned projects via loader on the team entity' do
      team_record = TeamRecord.create!(name: 'Platform Team')
      project = build_project('Feature A')
      project_repository.save(project)
      repository.link_owned_project(team_id: team_record.id, project: project, order: 0)

      loaded_team = repository.find(team_record.id)

      expect(loaded_team.owned_projects.map(&:name)).to eq(['Feature A'])
    end

    it 'rolls up health from owned projects' do
      team_record = TeamRecord.create!(name: 'Platform Team')
      project_record = ProjectRecord.create!(name: 'Feature A', current_state: 'in_progress')
      HealthUpdateRecord.create!(project: project_record, date: Date.current, health: 'on_track')
      TeamsProjectRecord.create!(team: team_record, project: project_record, order: 0)

      loaded_team = repository.find(team_record.id)

      expect(loaded_team.health).to eq(:on_track)
    end

    it 'checks if an owned project relationship exists' do
      team = TeamRecord.create!(name: 'Platform Team')
      project = ProjectRecord.create!(name: 'Feature A')
      TeamsProjectRecord.create!(team: team, project: project, order: 0)

      expect(repository.owned_project_exists?(team_id: team.id, project_id: project.id)).to be(true)
      expect(repository.owned_project_exists?(team_id: team.id, project_id: 999)).to be(false)
    end

    it 'unlinks an owned project' do
      team = TeamRecord.create!(name: 'Platform Team')
      project = ProjectRecord.create!(name: 'Feature A')
      TeamsProjectRecord.create!(team: team, project: project, order: 0)

      repository.unlink_owned_project(team_id: team.id, project_id: project.id)

      expect(TeamsProjectRecord.where(team: team, project: project)).to be_empty
    end
  end

  describe 'subordinate team relationships' do
    it 'links subordinate teams and tracks order' do
      parent = TeamRecord.create!(name: 'Platform')
      child = TeamRecord.create!(name: 'Mobile')
      child_team = build_team('Mobile')

      repository.link_subordinate_team(parent_id: parent.id, child: child_team, order: 0)

      relationships = repository.subordinate_teams_for(parent_id: parent.id)
      expect(relationships.first[:team].name).to eq('Mobile')
      expect(relationships.first[:order]).to eq(0)
    end

    it 'calculates next order for subordinate teams' do
      parent = TeamRecord.create!(name: 'Platform')
      TeamRecord.create!(name: 'Mobile')
      TeamRecord.create!(name: 'Web')

      expect(repository.next_subordinate_team_order(parent_id: parent.id)).to eq(0)

      repository.link_subordinate_team(parent_id: parent.id, child: build_team('Mobile'), order: 0)
      expect(repository.next_subordinate_team_order(parent_id: parent.id)).to eq(1)

      repository.link_subordinate_team(parent_id: parent.id, child: build_team('Web'), order: 1)
      expect(repository.next_subordinate_team_order(parent_id: parent.id)).to eq(2)
    end

    it 'lazy loads subordinate teams via loader on the team entity' do
      parent = TeamRecord.create!(name: 'Platform')
      TeamRecord.create!(name: 'Mobile')
      repository.link_subordinate_team(parent_id: parent.id, child: build_team('Mobile'), order: 0)

      loaded_team = repository.find(parent.id)

      expect(loaded_team.subordinate_teams.map(&:name)).to eq(['Mobile'])
    end

    it 'checks if a subordinate team relationship exists' do
      parent = TeamRecord.create!(name: 'Platform')
      child = TeamRecord.create!(name: 'Mobile')
      TeamsTeamRecord.create!(parent: parent, child: child, order: 0)

      expect(repository.subordinate_team_exists?(parent_id: parent.id, child_id: child.id)).to be(true)
      expect(repository.subordinate_team_exists?(parent_id: parent.id, child_id: 999)).to be(false)
    end

    it 'unlinks a subordinate team' do
      parent = TeamRecord.create!(name: 'Platform')
      child = TeamRecord.create!(name: 'Mobile')
      TeamsTeamRecord.create!(parent: parent, child: child, order: 0)

      repository.unlink_subordinate_team(parent_id: parent.id, child_id: child.id)

      expect(TeamsTeamRecord.where(parent: parent, child: child)).to be_empty
    end

    it 'checks if team has subordinate teams' do
      parent = TeamRecord.create!(name: 'Platform')
      child = TeamRecord.create!(name: 'Mobile')

      expect(repository.has_subordinate_teams?(team_id: parent.id)).to be(false)

      TeamsTeamRecord.create!(parent: parent, child: child, order: 0)

      expect(repository.has_subordinate_teams?(team_id: parent.id)).to be(true)
    end

    it 'checks if team has owned projects' do
      team = TeamRecord.create!(name: 'Platform')
      project = ProjectRecord.create!(name: 'Feature A')

      expect(repository.has_owned_projects?(team_id: team.id)).to be(false)

      TeamsProjectRecord.create!(team: team, project: project, order: 0)

      expect(repository.has_owned_projects?(team_id: team.id)).to be(true)
    end
  end

  describe '#all_active_roots' do
    it 'returns all non-archived root teams' do
      TeamRecord.create!(name: 'Root 1', archived: false)
      TeamRecord.create!(name: 'Root 2', archived: false)
      TeamRecord.create!(name: 'Archived', archived: true)

      result = repository.all_active_roots

      expect(result.map(&:name)).to match_array(['Root 1', 'Root 2'])
    end

    it 'excludes child teams' do
      parent = TeamRecord.create!(name: 'Parent', archived: false)
      child = TeamRecord.create!(name: 'Child', archived: false)
      TeamsTeamRecord.create!(parent: parent, child: child, order: 0)

      result = repository.all_active_roots

      expect(result.map(&:name)).to eq(['Parent'])
    end

    it 'returns empty array when no teams exist' do
      result = repository.all_active_roots

      expect(result).to eq([])
    end
  end

  describe '#all_archived_roots' do
    it 'returns all archived root teams' do
      TeamRecord.create!(name: 'Root Active', archived: false)
      TeamRecord.create!(name: 'Archived 1', archived: true)
      TeamRecord.create!(name: 'Archived 2', archived: true)

      result = repository.all_archived_roots

      expect(result.map(&:name)).to match_array(['Archived 1', 'Archived 2'])
    end

    it 'excludes child teams' do
      parent = TeamRecord.create!(name: 'Archived Parent', archived: true)
      child = TeamRecord.create!(name: 'Archived Child', archived: true)
      TeamsTeamRecord.create!(parent: parent, child: child, order: 0)

      result = repository.all_archived_roots

      expect(result.map(&:name)).to eq(['Archived Parent'])
    end
  end

  describe 'parent_team loading' do
    it 'lazy loads parent team via loader on the team entity' do
      parent = TeamRecord.create!(name: 'Platform', point_of_contact: 'Alice')
      child = TeamRecord.create!(name: 'Mobile')
      TeamsTeamRecord.create!(parent: parent, child: child, order: 0)

      loaded_child = repository.find(child.id)

      expect(loaded_child.parent_team.name).to eq('Platform')
    end

    it 'returns nil when team has no parent' do
      team = TeamRecord.create!(name: 'Root Team')

      loaded_team = repository.find(team.id)

      expect(loaded_team.parent_team).to be_nil
    end
  end

  describe 'effective_contact traversal' do
    it 'inherits contact from parent team when own is blank' do
      parent = TeamRecord.create!(name: 'Platform', point_of_contact: 'Alice')
      child = TeamRecord.create!(name: 'Mobile', point_of_contact: '')
      TeamsTeamRecord.create!(parent: parent, child: child, order: 0)

      loaded_child = repository.find(child.id)

      expect(loaded_child.effective_contact).to eq('Alice')
    end

    it 'traverses multiple levels to find contact' do
      grandparent = TeamRecord.create!(name: 'Engineering', point_of_contact: 'Carol')
      parent = TeamRecord.create!(name: 'Platform', point_of_contact: '')
      child = TeamRecord.create!(name: 'Mobile', point_of_contact: '')
      TeamsTeamRecord.create!(parent: grandparent, child: parent, order: 0)
      TeamsTeamRecord.create!(parent: parent, child: child, order: 0)

      loaded_child = repository.find(child.id)

      expect(loaded_child.effective_contact).to eq('Carol')
    end
  end
end
