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

  describe '#weekly_for_project' do
    it 'returns 6 Mondays in ascending order when no current week updates' do
      project = ProjectRecord.create!(name: 'Beta', description: '', point_of_contact: '')
      repository = described_class.new

      updates = repository.weekly_for_project(project.id)

      expect(updates.length).to eq(6)
      updates.each { |u| expect(u.date.wday).to eq(1) }
      expect(updates.map(&:date)).to eq(updates.map(&:date).sort)
    end

    it 'adjusts most_recent_monday when today is Monday' do
      project = ProjectRecord.create!(name: 'MondayTest', description: '', point_of_contact: '')
      repository = described_class.new

      # Find next Monday from today
      today = Date.current
      days_until_monday = (1 - today.wday) % 7
      days_until_monday = 7 if days_until_monday == 0
      next_monday = today + days_until_monday

      # Use travel_to for time manipulation instead of stubbing Date.current
      travel_to(next_monday) do
        updates = repository.weekly_for_project(project.id)

        expect(updates.length).to eq(6)
        # Most recent Monday should be last week, not today
        expect(updates.last.date).to eq(next_monday - 7)
      end
    end

    it 'uses this week Monday when today is not Monday' do
      project = ProjectRecord.create!(name: 'TuesdayTest', description: '', point_of_contact: '')
      repository = described_class.new

      # Travel to a Tuesday to ensure the else branch is hit
      tuesday = Date.new(2025, 12, 16) # December 16, 2025 is a Tuesday
      travel_to(tuesday) do
        updates = repository.weekly_for_project(project.id)

        expect(updates.length).to eq(6)
        # Most recent Monday should be this week's Monday (December 15)
        expect(updates.last.date).to eq(Date.new(2025, 12, 15))
      end
    end

    it 'returns empty when last_six_mondays returns empty' do
      project = ProjectRecord.create!(name: 'EmptyMondays', description: '', point_of_contact: '')
      repository = described_class.new

      allow(repository).to receive(:last_six_mondays).and_return([])

      updates = repository.weekly_for_project(project.id)

      expect(updates).to eq([])
    end

    it 'returns nil from latest_update_after_monday when last_monday is nil' do
      project = ProjectRecord.create!(name: 'NilMonday', description: '', point_of_contact: '')
      repository = described_class.new

      result = repository.send(:latest_update_after_monday, [], nil)

      expect(result).to be_nil
    end

    it 'returns :not_available for Mondays with no prior updates' do
      project = ProjectRecord.create!(name: 'Gamma', description: '', point_of_contact: '')
      repository = described_class.new

      updates = repository.weekly_for_project(project.id)

      expect(updates.map(&:health)).to all(eq(:not_available))
    end

    it 'uses most recent update as of each Monday' do
      project = ProjectRecord.create!(name: 'Delta', description: '', point_of_contact: '')
      repository = described_class.new

      today = Date.current
      last_monday = today - ((today.wday - 1) % 7)
      last_monday -= 7 if last_monday >= today

      HealthUpdateRecord.create!(project: project, date: last_monday - 10, health: 'off_track')
      HealthUpdateRecord.create!(project: project, date: last_monday - 3, health: 'on_track')

      updates = repository.weekly_for_project(project.id)
      monday_update = updates.find { |u| u.date == last_monday }

      expect(monday_update.health).to eq(:on_track)
    end

    it 'includes current week update after the last Monday' do
      project = ProjectRecord.create!(name: 'Epsilon', description: '', point_of_contact: '')
      repository = described_class.new

      today = Date.current
      last_monday = today - ((today.wday - 1) % 7)
      last_monday -= 7 if last_monday >= today

      HealthUpdateRecord.create!(project: project, date: last_monday + 2, health: 'at_risk', description: 'Current week')

      updates = repository.weekly_for_project(project.id)

      expect(updates.length).to eq(7)
      expect(updates.last.date).to eq(last_monday + 2)
      expect(updates.last.health).to eq(:at_risk)
      expect(updates.last.description).to eq('Current week')
    end
  end

  describe '#all' do
    it 'returns all health updates ordered by date descending' do
      project = ProjectRecord.create!(name: 'AllUpdates', description: '', point_of_contact: '')
      HealthUpdateRecord.create!(project: project, date: Date.new(2025, 1, 1), health: 'on_track')
      HealthUpdateRecord.create!(project: project, date: Date.new(2025, 1, 10), health: 'off_track')
      repository = described_class.new

      updates = repository.all

      expect(updates.length).to eq(2)
      expect(updates.first.date).to eq(Date.new(2025, 1, 10))
      expect(updates.last.date).to eq(Date.new(2025, 1, 1))
    end
  end

  describe '#latest_for_project' do
    it 'returns the most recent update for a project' do
      project = ProjectRecord.create!(name: 'LatestUpdate', description: '', point_of_contact: '')
      HealthUpdateRecord.create!(project: project, date: Date.new(2025, 1, 1), health: 'on_track')
      HealthUpdateRecord.create!(project: project, date: Date.new(2025, 1, 10), health: 'off_track')
      repository = described_class.new

      latest = repository.latest_for_project(project.id)

      expect(latest.date).to eq(Date.new(2025, 1, 10))
      expect(latest.health).to eq(:off_track)
    end

    it 'returns nil when no updates exist' do
      project = ProjectRecord.create!(name: 'NoUpdates', description: '', point_of_contact: '')
      repository = described_class.new

      latest = repository.latest_for_project(project.id)

      expect(latest).to be_nil
    end
  end
end
