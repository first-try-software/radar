require 'rails_helper'
require 'domain/projects/project'
require 'domain/projects/project_attributes'
require 'domain/projects/project_loaders'
require Rails.root.join('app/persistence/project_repository')
require Rails.root.join('app/persistence/health_update_repository')

RSpec.describe ProjectRepository do
  let(:health_repository) { HealthUpdateRepository.new }
  subject(:repository) { described_class.new(health_update_repository: health_repository) }

  def build_project(name, current_state: :new)
    attrs = ProjectAttributes.new(name: name, current_state: current_state)
    Project.new(attributes: attrs)
  end

  it 'loads health updates into the domain project' do
    project_record = ProjectRecord.create!(
      name: 'Status',
      description: 'Status dashboard',
      point_of_contact: 'Alex',
      current_state: 'in_progress'
    )
    HealthUpdateRecord.create!(project: project_record, date: Date.new(2025, 1, 1), health: 'at_risk')
    HealthUpdateRecord.create!(project: project_record, date: Date.new(2025, 1, 8), health: 'on_track')

    project = repository.find(project_record.id)

    expect(project.health).to eq(:on_track)
    expect(project.health_trend).not_to be_empty
    expect(project.health_trend.last.health).to eq(:on_track)
  end

  describe '#find' do
    it 'finds projects by id' do
      record = ProjectRecord.create!(name: 'Status')

      result = repository.find(record.id)

      expect(result.name).to eq('Status')
    end
  end

  describe '#update' do
    it 'updates projects by id' do
      record = ProjectRecord.create!(name: 'Status')
      project = build_project('Updated')

      repository.update(id: record.id, project: project)

      expect(repository.find(record.id).name).to eq('Updated')
    end

    it 'returns nil when project not found' do
      project = build_project('Updated')

      result = repository.update(id: 999, project: project)

      expect(result).to be_nil
    end
  end

  describe '#update_by_name' do
    it 'updates projects by name' do
      record = ProjectRecord.create!(name: 'Status', current_state: 'new')
      project = build_project('Status', current_state: :done)

      repository.update_by_name(name: 'Status', project: project)

      expect(repository.find(record.id).current_state).to eq(:done)
    end

    it 'returns nil when project not found by name' do
      project = build_project('NonExistent', current_state: :done)

      result = repository.update_by_name(name: 'NonExistent', project: project)

      expect(result).to be_nil
    end
  end

  describe '#save' do
    it 'saves new projects without specifying an id' do
      project = build_project('Status')

      repository.save(project)

      expect(repository.exists_with_name?('Status')).to be(true)
    end
  end

  describe '#exists_with_name?' do
    it 'checks for existing names' do
      ProjectRecord.create!(name: 'Status')

      expect(repository.exists_with_name?('Status')).to be(true)
      expect(repository.exists_with_name?('Other')).to be(false)
    end
  end

  describe 'subordinate relationships' do
    it 'links subordinate projects and tracks order' do
      parent = ProjectRecord.create!(name: 'Parent')
      child = build_project('Child')
      repository.save(child)

      repository.link_subordinate(parent_id: parent.id, child: child, order: 0)

      relationship = repository.subordinate_relationships_for(parent_id: parent.id).first
      expect(relationship[:child].name).to eq('Child')
      expect(relationship[:parent_id]).to eq(parent.id.to_s)
      expect(repository.next_subordinate_order(parent_id: parent.id)).to eq(1)
    end

    it 'lazy loads children via loader on the parent entity' do
      parent = ProjectRecord.create!(name: 'Parent')
      child = build_project('Child')
      child_record = repository.save(child)

      repository.link_subordinate(parent_id: parent.id, child: child, order: 0)

      loaded_parent = repository.find(parent.id)
      expect(loaded_parent.children.map(&:name)).to eq(['Child'])
    end

    it 'lazy loads parent via loader on the child entity' do
      parent = ProjectRecord.create!(name: 'Parent')
      child = build_project('Child')
      repository.save(child)

      repository.link_subordinate(parent_id: parent.id, child: child, order: 0)

      child_record = ProjectRecord.find_by(name: 'Child')
      loaded_child = repository.find(child_record.id)

      expect(loaded_child.parent.name).to eq('Parent')
    end

    it 'returns nil parent when project has no parent' do
      record = ProjectRecord.create!(name: 'Orphan')

      loaded_project = repository.find(record.id)

      expect(loaded_project.parent).to be_nil
    end

    it 'scopes subordinate ordering per parent' do
      parent_one = ProjectRecord.create!(name: 'Parent 1')
      parent_two = ProjectRecord.create!(name: 'Parent 2')
      first_child = build_project('FirstChild')
      second_child = build_project('SecondChild')
      repository.save(first_child)
      repository.save(second_child)

      repository.link_subordinate(parent_id: parent_one.id, child: first_child, order: 0)
      repository.link_subordinate(parent_id: parent_two.id, child: second_child, order: 0)

      expect(repository.next_subordinate_order(parent_id: parent_one.id)).to eq(1)
      expect(repository.next_subordinate_order(parent_id: parent_two.id)).to eq(1)
    end

    it 'enforces a single parent per child' do
      parent_one = ProjectRecord.create!(name: 'Parent 1')
      parent_two = ProjectRecord.create!(name: 'Parent 2')
      child = build_project('Child')
      repository.save(child)

      repository.link_subordinate(parent_id: parent_one.id, child: child, order: 0)

      expect {
        repository.link_subordinate(parent_id: parent_two.id, child: child, order: 0)
      }.to raise_error(/already has a parent/)
    end

    it 'rejects linking the same child twice to the same parent' do
      parent = ProjectRecord.create!(name: 'Parent')
      child = build_project('Child')
      repository.save(child)

      repository.link_subordinate(parent_id: parent.id, child: child, order: 0)

      expect {
        repository.link_subordinate(parent_id: parent.id, child: child, order: 1)
      }.to raise_error(/already has a parent/)
    end
  end

  describe '#all_active_roots' do
    it 'returns non-archived root projects' do
      ProjectRecord.create!(name: 'Active Root')
      ProjectRecord.create!(name: 'Archived', archived: true)

      roots = repository.all_active_roots

      expect(roots.map(&:name)).to eq(['Active Root'])
    end

    it 'excludes child projects' do
      parent = ProjectRecord.create!(name: 'Parent')
      child = build_project('Child')
      repository.save(child)
      repository.link_subordinate(parent_id: parent.id, child: child, order: 0)

      roots = repository.all_active_roots

      expect(roots.map(&:name)).to eq(['Parent'])
    end

    it 'includes project id in returned entities' do
      record = ProjectRecord.create!(name: 'WithId')

      roots = repository.all_active_roots

      expect(roots.first.id).to eq(record.id.to_s)
    end
  end

  describe '#orphan_projects' do
    it 'returns projects without parent or team' do
      ProjectRecord.create!(name: 'Orphan')

      orphans = repository.orphan_projects

      expect(orphans.map(&:name)).to eq(['Orphan'])
    end

    it 'excludes archived projects' do
      ProjectRecord.create!(name: 'Archived Orphan', archived: true)

      orphans = repository.orphan_projects

      expect(orphans).to be_empty
    end

    it 'excludes projects with a parent' do
      parent = ProjectRecord.create!(name: 'Parent')
      child = ProjectRecord.create!(name: 'Child')
      ProjectsProjectRecord.create!(parent: parent, child: child, order: 0)

      orphans = repository.orphan_projects

      expect(orphans.map(&:name)).to eq(['Parent'])
    end

    it 'excludes projects owned by a team' do
      project = ProjectRecord.create!(name: 'Team Owned')
      team = TeamRecord.create!(name: 'Team')
      TeamsProjectRecord.create!(team: team, project: project, order: 0)

      orphans = repository.orphan_projects

      expect(orphans).to be_empty
    end
  end

  describe 'owning_team loading' do
    it 'returns nil when project has no owning team and team_repository not set' do
      record = ProjectRecord.create!(name: 'Orphan')

      loaded = repository.find(record.id)

      expect(loaded.owning_team).to be_nil
    end

    it 'returns nil when project has no owning team' do
      team_repository = TeamRepository.new(project_repository: repository)
      repository.team_repository = team_repository
      record = ProjectRecord.create!(name: 'Orphan')

      loaded = repository.find(record.id)

      expect(loaded.owning_team).to be_nil
    end

    it 'lazy loads owning team via loader' do
      team_repository = TeamRepository.new(project_repository: repository)
      repository.team_repository = team_repository
      team = TeamRecord.create!(name: 'Platform', point_of_contact: 'Alice')
      project = ProjectRecord.create!(name: 'Feature A')
      TeamsProjectRecord.create!(team: team, project: project, order: 0)

      loaded = repository.find(project.id)

      expect(loaded.owning_team.name).to eq('Platform')
    end
  end

  describe 'effective_contact traversal' do
    it 'inherits contact from owning team when project has no contact' do
      team_repository = TeamRepository.new(project_repository: repository)
      repository.team_repository = team_repository
      team = TeamRecord.create!(name: 'Platform', point_of_contact: 'Alice')
      project = ProjectRecord.create!(name: 'Feature A', point_of_contact: '')
      TeamsProjectRecord.create!(team: team, project: project, order: 0)

      loaded = repository.find(project.id)

      expect(loaded.effective_contact).to eq('Alice')
    end

    it 'traverses project hierarchy before team hierarchy' do
      team_repository = TeamRepository.new(project_repository: repository)
      repository.team_repository = team_repository
      team = TeamRecord.create!(name: 'Platform', point_of_contact: 'TeamContact')
      parent = ProjectRecord.create!(name: 'Parent', point_of_contact: 'ParentContact')
      child = ProjectRecord.create!(name: 'Child', point_of_contact: '')
      ProjectsProjectRecord.create!(parent: parent, child: child, order: 0)
      TeamsProjectRecord.create!(team: team, project: parent, order: 0)

      loaded = repository.find(child.id)

      expect(loaded.effective_contact).to eq('ParentContact')
    end
  end
end
