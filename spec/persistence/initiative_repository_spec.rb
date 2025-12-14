require 'rails_helper'
require 'domain/initiatives/initiative'
require 'domain/projects/project'
require 'domain/projects/project_attributes'
require Rails.root.join('app/persistence/initiative_repository')
require Rails.root.join('app/persistence/project_repository')
require Rails.root.join('app/persistence/health_update_repository')

RSpec.describe InitiativeRepository do
  let(:health_repository) { HealthUpdateRepository.new }
  let(:project_repository) { ProjectRepository.new(health_update_repository: health_repository) }
  subject(:repository) { described_class.new(project_repository: project_repository) }

  def build_initiative(name)
    Initiative.new(name: name)
  end

  def build_project(name)
    attrs = ProjectAttributes.new(name: name)
    Project.new(attributes: attrs)
  end

  describe '#find' do
    it 'finds initiatives by id' do
      record = InitiativeRecord.create!(name: 'Launch 2025')

      result = repository.find(record.id)

      expect(result.name).to eq('Launch 2025')
    end

    it 'returns nil when not found' do
      result = repository.find(999)

      expect(result).to be_nil
    end

    it 'maps archived flag correctly' do
      record = InitiativeRecord.create!(name: 'Archived', archived: true)

      result = repository.find(record.id)

      expect(result.archived?).to be(true)
    end
  end

  describe '#save' do
    it 'saves new initiatives' do
      initiative = build_initiative('Launch 2025')

      repository.save(initiative)

      expect(repository.exists_with_name?('Launch 2025')).to be(true)
    end
  end

  describe '#update' do
    it 'updates initiatives by id' do
      record = InitiativeRecord.create!(name: 'Launch 2025')
      updated = Initiative.new(name: 'Launch 2026', description: 'Updated desc')

      repository.update(id: record.id, initiative: updated)

      result = repository.find(record.id)
      expect(result.name).to eq('Launch 2026')
      expect(result.description).to eq('Updated desc')
    end

    it 'returns nil when initiative not found' do
      initiative = build_initiative('NonExistent')

      result = repository.update(id: 999, initiative: initiative)

      expect(result).to be_nil
    end
  end

  describe '#update_state' do
    it 'updates initiative state by id' do
      record = InitiativeRecord.create!(name: 'Launch 2025', current_state: 'new')

      repository.update_state(id: record.id, state: :in_progress)

      result = repository.find(record.id)
      expect(result.current_state).to eq(:in_progress)
    end

    it 'returns nil when initiative not found' do
      result = repository.update_state(id: 999, state: :in_progress)

      expect(result).to be_nil
    end
  end

  describe '#exists_with_name?' do
    it 'checks for existing names' do
      InitiativeRecord.create!(name: 'Launch 2025')

      expect(repository.exists_with_name?('Launch 2025')).to be(true)
      expect(repository.exists_with_name?('Other')).to be(false)
    end
  end

  describe 'related project relationships' do
    it 'links related projects and tracks order' do
      initiative = InitiativeRecord.create!(name: 'Launch 2025')
      project = build_project('Feature A')
      project_repository.save(project)

      repository.link_related_project(initiative_id: initiative.id, project: project, order: 0)

      relationships = repository.related_projects_for(initiative_id: initiative.id)
      expect(relationships.first[:project].name).to eq('Feature A')
      expect(relationships.first[:order]).to eq(0)
    end

    it 'calculates next order for related projects' do
      initiative = InitiativeRecord.create!(name: 'Launch 2025')
      project_one = build_project('Feature A')
      project_two = build_project('Feature B')
      project_repository.save(project_one)
      project_repository.save(project_two)

      expect(repository.next_related_project_order(initiative_id: initiative.id)).to eq(0)

      repository.link_related_project(initiative_id: initiative.id, project: project_one, order: 0)
      expect(repository.next_related_project_order(initiative_id: initiative.id)).to eq(1)

      repository.link_related_project(initiative_id: initiative.id, project: project_two, order: 1)
      expect(repository.next_related_project_order(initiative_id: initiative.id)).to eq(2)
    end

    it 'lazy loads related projects via loader on the initiative entity' do
      initiative_record = InitiativeRecord.create!(name: 'Launch 2025')
      project = build_project('Feature A')
      project_repository.save(project)
      repository.link_related_project(initiative_id: initiative_record.id, project: project, order: 0)

      loaded_initiative = repository.find(initiative_record.id)

      expect(loaded_initiative.related_projects.map(&:name)).to eq(['Feature A'])
    end

    it 'rolls up health from related projects' do
      initiative_record = InitiativeRecord.create!(name: 'Launch 2025')
      project_record = ProjectRecord.create!(name: 'Feature A', current_state: 'in_progress')
      HealthUpdateRecord.create!(project: project_record, date: Date.current, health: 'on_track')
      InitiativesProjectRecord.create!(initiative: initiative_record, project: project_record, order: 0)

      loaded_initiative = repository.find(initiative_record.id)

      expect(loaded_initiative.health).to eq(:on_track)
    end

    it 'checks if a related project relationship exists' do
      initiative = InitiativeRecord.create!(name: 'Launch 2025')
      project = ProjectRecord.create!(name: 'Feature A')
      InitiativesProjectRecord.create!(initiative: initiative, project: project, order: 0)

      expect(repository.related_project_exists?(initiative_id: initiative.id, project_id: project.id)).to be(true)
      expect(repository.related_project_exists?(initiative_id: initiative.id, project_id: 999)).to be(false)
    end

    it 'unlinks a related project' do
      initiative = InitiativeRecord.create!(name: 'Launch 2025')
      project = ProjectRecord.create!(name: 'Feature A')
      InitiativesProjectRecord.create!(initiative: initiative, project: project, order: 0)

      repository.unlink_related_project(initiative_id: initiative.id, project_id: project.id)

      expect(InitiativesProjectRecord.where(initiative: initiative, project: project)).to be_empty
    end

    it 'allows linking a project to multiple initiatives' do
      initiative1 = InitiativeRecord.create!(name: 'Launch 2025')
      initiative2 = InitiativeRecord.create!(name: 'Launch 2026')
      project = build_project('Shared Project')
      project_repository.save(project)

      repository.link_related_project(initiative_id: initiative1.id, project: project, order: 0)
      repository.link_related_project(initiative_id: initiative2.id, project: project, order: 0)

      expect(InitiativesProjectRecord.where(project_id: ProjectRecord.find_by(name: 'Shared Project').id).count).to eq(2)
    end
  end
end
