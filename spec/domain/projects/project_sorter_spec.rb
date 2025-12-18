require 'rails_helper'
require 'domain/projects/project_sorter'

RSpec.describe ProjectSorter do
  def build_project(name:, state:, health:, last_update_date: nil)
    project = instance_double(
      'Project',
      name: name,
      current_state: state,
      health: health
    )

    if last_update_date
      update = instance_double('HealthUpdate', date: last_update_date)
      allow(project).to receive(:latest_health_update).and_return(update)
    else
      allow(project).to receive(:latest_health_update).and_return(nil)
    end

    project
  end

  describe '#sorted' do
    it 'sorts by state first (blocked before in_progress)' do
      blocked = build_project(name: 'Z', state: :blocked, health: :on_track)
      in_progress = build_project(name: 'A', state: :in_progress, health: :off_track)

      sorter = ProjectSorter.new([in_progress, blocked])
      result = sorter.sorted

      expect(result).to eq([blocked, in_progress])
    end

    it 'sorts by health within same state (off_track before at_risk)' do
      off_track = build_project(name: 'Z', state: :in_progress, health: :off_track)
      at_risk = build_project(name: 'A', state: :in_progress, health: :at_risk)

      sorter = ProjectSorter.new([at_risk, off_track])
      result = sorter.sorted

      expect(result).to eq([off_track, at_risk])
    end

    it 'sorts by last update date within same state and health (oldest first)' do
      old = build_project(name: 'Z', state: :in_progress, health: :at_risk, last_update_date: Date.new(2024, 1, 1))
      new = build_project(name: 'A', state: :in_progress, health: :at_risk, last_update_date: Date.new(2024, 12, 1))

      sorter = ProjectSorter.new([new, old])
      result = sorter.sorted

      expect(result).to eq([old, new])
    end

    it 'sorts projects with no update before projects with updates' do
      no_update = build_project(name: 'Z', state: :in_progress, health: :at_risk)
      has_update = build_project(name: 'A', state: :in_progress, health: :at_risk, last_update_date: Date.new(2024, 1, 1))

      sorter = ProjectSorter.new([has_update, no_update])
      result = sorter.sorted

      expect(result).to eq([no_update, has_update])
    end

    it 'sorts by name within same state, health, and update date' do
      apple = build_project(name: 'Apple', state: :in_progress, health: :at_risk)
      banana = build_project(name: 'Banana', state: :in_progress, health: :at_risk)

      sorter = ProjectSorter.new([banana, apple])
      result = sorter.sorted

      expect(result).to eq([apple, banana])
    end

    it 'sorts case-insensitively by name' do
      upper = build_project(name: 'APPLE', state: :in_progress, health: :at_risk)
      lower = build_project(name: 'banana', state: :in_progress, health: :at_risk)

      sorter = ProjectSorter.new([lower, upper])
      result = sorter.sorted

      expect(result).to eq([upper, lower])
    end

    it 'applies full state ordering: blocked, in_progress, new, todo, on_hold, done' do
      done = build_project(name: 'A', state: :done, health: :on_track)
      on_hold = build_project(name: 'B', state: :on_hold, health: :on_track)
      todo = build_project(name: 'C', state: :todo, health: :on_track)
      new_proj = build_project(name: 'D', state: :new, health: :on_track)
      in_progress = build_project(name: 'E', state: :in_progress, health: :on_track)
      blocked = build_project(name: 'F', state: :blocked, health: :on_track)

      sorter = ProjectSorter.new([done, on_hold, todo, new_proj, in_progress, blocked])
      result = sorter.sorted

      expect(result).to eq([blocked, in_progress, new_proj, todo, on_hold, done])
    end

    it 'applies full health ordering: off_track, at_risk, on_track, not_available' do
      not_available = build_project(name: 'A', state: :in_progress, health: :not_available)
      on_track = build_project(name: 'B', state: :in_progress, health: :on_track)
      at_risk = build_project(name: 'C', state: :in_progress, health: :at_risk)
      off_track = build_project(name: 'D', state: :in_progress, health: :off_track)

      sorter = ProjectSorter.new([not_available, on_track, at_risk, off_track])
      result = sorter.sorted

      expect(result).to eq([off_track, at_risk, on_track, not_available])
    end

    it 'handles nil state by treating as done' do
      nil_state = build_project(name: 'A', state: nil, health: :on_track)
      in_progress = build_project(name: 'B', state: :in_progress, health: :on_track)

      sorter = ProjectSorter.new([nil_state, in_progress])
      result = sorter.sorted

      expect(result).to eq([in_progress, nil_state])
    end

    it 'handles nil health by treating as not_available' do
      nil_health = build_project(name: 'A', state: :in_progress, health: nil)
      on_track = build_project(name: 'B', state: :in_progress, health: :on_track)

      sorter = ProjectSorter.new([nil_health, on_track])
      result = sorter.sorted

      expect(result).to eq([on_track, nil_health])
    end

    it 'handles empty collection' do
      sorter = ProjectSorter.new([])
      result = sorter.sorted

      expect(result).to eq([])
    end

    it 'handles single project' do
      project = build_project(name: 'Solo', state: :in_progress, health: :on_track)

      sorter = ProjectSorter.new([project])
      result = sorter.sorted

      expect(result).to eq([project])
    end
  end
end
