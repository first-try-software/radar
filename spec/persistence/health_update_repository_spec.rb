require 'rails_helper'
require 'domain/projects/health_update'
require Rails.root.join('app/persistence/health_update_repository')

RSpec.describe HealthUpdateRepository do
  describe '#save' do
    it 'persists the health update' do
      project = ProjectRecord.create!(name: 'Status', description: '', point_of_contact: '')
      update = HealthUpdate.new(project_id: project.id, date: Date.new(2025, 1, 1), health: :on_track)
      repository = described_class.new

      repository.save(update)

      record = HealthUpdateRecord.last
      expect(record.project_id).to eq(project.id)
      expect(record.health).to eq('on_track')
      expect(record.date).to eq(Date.new(2025, 1, 1))
    end
  end

  describe '#all_for_project' do
    it 'returns domain health updates ordered by date' do
      project = ProjectRecord.create!(name: 'Alpha', description: '', point_of_contact: '')
      earlier = HealthUpdateRecord.create!(project: project, date: Date.new(2025, 1, 1), health: 'off_track')
      later = HealthUpdateRecord.create!(project: project, date: Date.new(2025, 1, 8), health: 'at_risk')
      repository = described_class.new

      updates = repository.all_for_project(project.id)

      expect(updates.map(&:project_id)).to all(eq(project.id.to_s))
      expect(updates.map(&:health)).to eq([:off_track, :at_risk])
      expect(updates.map(&:date)).to eq([earlier.date, later.date])
    end
  end
end
