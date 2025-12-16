require 'rails_helper'
require Rails.root.join('lib/domain/projects/project_trend_service')

RSpec.describe ProjectTrendService do
  describe '#call' do
    it 'returns empty trend data when health_update_repository is nil' do
      project = build_project(id: 1, health: :on_track)
      service = ProjectTrendService.new(project: project, health_update_repository: nil)

      result = service.call

      expect(result[:trend_data]).to eq([])
      expect(result[:weeks_of_data]).to eq(0)
    end

    it 'returns empty trend data when project has no health updates' do
      project = build_project(id: 1, health: :not_available)
      repo = build_repo_with_updates([])
      service = ProjectTrendService.new(project: project, health_update_repository: repo)

      result = service.call

      expect(result[:trend_data]).to eq([])
      expect(result[:weeks_of_data]).to eq(0)
    end

    it 'returns trend data points for weeks with health updates' do
      project = build_project(id: 1, health: :on_track)
      repo = build_repo_with_updates([
        { project_id: 1, date: monday_weeks_ago(2), health: :at_risk },
        { project_id: 1, date: monday_weeks_ago(1), health: :on_track }
      ])
      service = ProjectTrendService.new(project: project, health_update_repository: repo)

      result = service.call

      expect(result[:trend_data].length).to be >= 2
      expect(result[:weeks_of_data]).to be >= 2
    end

    it 'calculates weekly health scores from project updates' do
      project = build_project(id: 1, health: :on_track)
      repo = build_repo_with_updates([
        { project_id: 1, date: monday_weeks_ago(2), health: :off_track },
        { project_id: 1, date: monday_weeks_ago(1), health: :on_track }
      ])
      service = ProjectTrendService.new(project: project, health_update_repository: repo)

      result = service.call
      scores = result[:trend_data].map { |d| d[:score] }

      expect(scores).to include(-1.0) # off_track week
      expect(scores).to include(1.0)  # on_track week
    end

    it 'averages multiple updates in the same week' do
      project = build_project(id: 1, health: :at_risk)
      repo = build_repo_with_updates([
        { project_id: 1, date: monday_weeks_ago(1), health: :on_track },
        { project_id: 1, date: monday_weeks_ago(1) + 2, health: :off_track }
      ])
      service = ProjectTrendService.new(project: project, health_update_repository: repo)

      result = service.call
      week_data = result[:trend_data].find { |d| d[:date] == monday_weeks_ago(1) }

      expect(week_data[:score]).to eq(0.0) # average of 1 and -1
    end

    it 'limits data to last 6 weeks' do
      project = build_project(id: 1, health: :on_track)
      updates = (1..10).map do |n|
        { project_id: 1, date: monday_weeks_ago(n), health: :on_track }
      end
      repo = build_repo_with_updates(updates)
      service = ProjectTrendService.new(project: project, health_update_repository: repo)

      result = service.call

      expect(result[:trend_data].length).to eq(6)
    end

    it 'classifies health as on_track when score >= 0.51' do
      project = build_project(id: 1, health: :on_track)
      repo = build_repo_with_updates([
        { project_id: 1, date: monday_weeks_ago(1), health: :on_track }
      ])
      service = ProjectTrendService.new(project: project, health_update_repository: repo)

      result = service.call

      expect(result[:trend_data].first[:health]).to eq(:on_track)
    end

    it 'classifies health as off_track when score <= -0.49' do
      project = build_project(id: 1, health: :off_track)
      repo = build_repo_with_updates([
        { project_id: 1, date: monday_weeks_ago(1), health: :off_track }
      ])
      service = ProjectTrendService.new(project: project, health_update_repository: repo)

      result = service.call

      expect(result[:trend_data].first[:health]).to eq(:off_track)
    end

    it 'classifies health as at_risk when score is between -0.49 and 0.51' do
      project = build_project(id: 1, health: :at_risk)
      repo = build_repo_with_updates([
        { project_id: 1, date: monday_weeks_ago(1), health: :at_risk }
      ])
      service = ProjectTrendService.new(project: project, health_update_repository: repo)

      result = service.call

      expect(result[:trend_data].first[:health]).to eq(:at_risk)
    end
  end

  describe 'trend direction' do
    it 'returns :up when health is improving' do
      project = build_project(id: 1, health: :on_track)
      repo = build_repo_with_updates([
        { project_id: 1, date: monday_weeks_ago(3), health: :off_track },
        { project_id: 1, date: monday_weeks_ago(2), health: :at_risk },
        { project_id: 1, date: monday_weeks_ago(1), health: :on_track }
      ])
      service = ProjectTrendService.new(project: project, health_update_repository: repo)

      result = service.call

      expect(result[:trend_direction]).to eq(:up)
    end

    it 'returns :down when health is declining' do
      project = build_project(id: 1, health: :off_track)
      repo = build_repo_with_updates([
        { project_id: 1, date: monday_weeks_ago(3), health: :on_track },
        { project_id: 1, date: monday_weeks_ago(2), health: :at_risk },
        { project_id: 1, date: monday_weeks_ago(1), health: :off_track }
      ])
      service = ProjectTrendService.new(project: project, health_update_repository: repo)

      result = service.call

      expect(result[:trend_direction]).to eq(:down)
    end

    it 'returns :stable when health is unchanged' do
      project = build_project(id: 1, health: :on_track)
      repo = build_repo_with_updates([
        { project_id: 1, date: monday_weeks_ago(2), health: :on_track },
        { project_id: 1, date: monday_weeks_ago(1), health: :on_track }
      ])
      service = ProjectTrendService.new(project: project, health_update_repository: repo)

      result = service.call

      expect(result[:trend_direction]).to eq(:stable)
    end

    it 'returns :stable when insufficient data' do
      project = build_project(id: 1, health: :on_track)
      repo = build_repo_with_updates([
        { project_id: 1, date: monday_weeks_ago(1), health: :on_track }
      ])
      service = ProjectTrendService.new(project: project, health_update_repository: repo)

      result = service.call

      expect(result[:trend_direction]).to eq(:stable)
    end
  end

  describe 'trend delta' do
    it 'calculates positive delta for improving trend' do
      project = build_project(id: 1, health: :on_track)
      repo = build_repo_with_updates([
        { project_id: 1, date: monday_weeks_ago(2), health: :off_track },
        { project_id: 1, date: monday_weeks_ago(1), health: :on_track }
      ])
      service = ProjectTrendService.new(project: project, health_update_repository: repo)

      result = service.call

      expect(result[:trend_delta]).to eq(2.0) # from -1 to 1
    end

    it 'calculates negative delta for declining trend' do
      project = build_project(id: 1, health: :off_track)
      repo = build_repo_with_updates([
        { project_id: 1, date: monday_weeks_ago(2), health: :on_track },
        { project_id: 1, date: monday_weeks_ago(1), health: :off_track }
      ])
      service = ProjectTrendService.new(project: project, health_update_repository: repo)

      result = service.call

      expect(result[:trend_delta]).to eq(-2.0) # from 1 to -1
    end

    it 'returns zero delta when insufficient data' do
      project = build_project(id: 1, health: :on_track)
      repo = build_repo_with_updates([])
      service = ProjectTrendService.new(project: project, health_update_repository: repo)

      result = service.call

      expect(result[:trend_delta]).to eq(0.0)
    end
  end

  describe 'confidence calculation' do
    it 'returns high confidence for consistent, fresh data' do
      project = build_project(id: 1, health: :on_track)
      repo = build_repo_with_updates([
        { project_id: 1, date: monday_weeks_ago(2), health: :on_track },
        { project_id: 1, date: monday_weeks_ago(1), health: :on_track },
        { project_id: 1, date: Date.current - 2, health: :on_track }
      ])
      service = ProjectTrendService.new(project: project, health_update_repository: repo)

      result = service.call

      expect(result[:confidence_level]).to eq(:high)
      expect(result[:confidence_score]).to be >= 70
    end

    it 'reduces confidence when data is stale (>14 days)' do
      project = build_project(id: 1, health: :on_track)
      # Use volatile data to reduce base score below 70 threshold
      repo = build_repo_with_updates([
        { project_id: 1, date: monday_weeks_ago(4), health: :on_track },
        { project_id: 1, date: monday_weeks_ago(3), health: :off_track }
      ])
      service = ProjectTrendService.new(project: project, health_update_repository: repo)

      result = service.call

      # Score reduced by staleness penalty (30) and variance
      expect(result[:confidence_score]).to be < 70
    end

    it 'applies staleness penalty when data is 7-14 days old' do
      project = build_project(id: 1, health: :on_track)
      repo = build_repo_with_updates([
        { project_id: 1, date: monday_weeks_ago(3), health: :on_track },
        { project_id: 1, date: monday_weeks_ago(2), health: :on_track },
        { project_id: 1, date: Date.current - 10, health: :on_track }
      ])
      service = ProjectTrendService.new(project: project, health_update_repository: repo)

      result = service.call

      # 7-14 days old should get 15% penalty
      expect(result[:confidence_score]).to be < 100
      expect(result[:confidence_score]).to be >= 70
    end

    it 'returns low confidence level when score is below 40' do
      project = build_project(id: 1, health: :on_track)
      # Stale data (>14 days = 30% penalty) + volatile data
      repo = build_repo_with_updates([
        { project_id: 1, date: monday_weeks_ago(5), health: :on_track },
        { project_id: 1, date: monday_weeks_ago(4), health: :off_track },
        { project_id: 1, date: monday_weeks_ago(3), health: :on_track }
      ])
      service = ProjectTrendService.new(project: project, health_update_repository: repo)

      result = service.call

      expect(result[:confidence_level]).to eq(:low)
      expect(result[:confidence_score]).to be < 40
    end

    it 'returns medium confidence level when score is between 40 and 69' do
      project = build_project(id: 1, health: :on_track)
      repo = build_repo_with_updates([
        { project_id: 1, date: monday_weeks_ago(2), health: :at_risk },
        { project_id: 1, date: monday_weeks_ago(1), health: :on_track },
        { project_id: 1, date: Date.current - 10, health: :on_track }
      ])
      service = ProjectTrendService.new(project: project, health_update_repository: repo)

      result = service.call

      expect(result[:confidence_level]).to eq(:medium)
    end

    it 'returns zero confidence when no data' do
      project = build_project(id: 1, health: :not_available)
      repo = build_repo_with_updates([])
      service = ProjectTrendService.new(project: project, health_update_repository: repo)

      result = service.call

      expect(result[:confidence_score]).to eq(0)
      expect(result[:confidence_level]).to eq(:low)
    end

    it 'returns zero confidence when no updates exist' do
      project = build_project(id: 1, health: :on_track)
      repo = build_repo_with_updates([])
      service = ProjectTrendService.new(project: project, health_update_repository: repo)

      result = service.call

      # With empty trend_data, confidence_score returns 0 early
      expect(result[:confidence_score]).to eq(0)
    end

    it 'floors confidence score at zero when penalties exceed base score' do
      project = build_project(id: 1, health: :on_track)
      # Highly volatile data (std_dev = 1.0 means 100% variance penalty) + stale (30% penalty)
      # This should push confidence below 0, which should be floored to 0
      repo = build_repo_with_updates([
        { project_id: 1, date: monday_weeks_ago(6), health: :on_track },
        { project_id: 1, date: monday_weeks_ago(5), health: :off_track },
        { project_id: 1, date: monday_weeks_ago(4), health: :on_track },
        { project_id: 1, date: monday_weeks_ago(3), health: :off_track }
      ])
      service = ProjectTrendService.new(project: project, health_update_repository: repo)

      result = service.call

      expect(result[:confidence_score]).to be >= 0
    end

    it 'floors base confidence at zero for extremely volatile data' do
      project = build_project(id: 1, health: :on_track)
      # Alternating on_track/off_track creates maximum volatility (std_dev = 1.0)
      repo = build_repo_with_updates([
        { project_id: 1, date: monday_weeks_ago(2), health: :on_track },
        { project_id: 1, date: monday_weeks_ago(2) + 1, health: :off_track },
        { project_id: 1, date: Date.current - 2, health: :on_track },
        { project_id: 1, date: Date.current - 1, health: :off_track }
      ])
      service = ProjectTrendService.new(project: project, health_update_repository: repo)

      result = service.call

      # With std_dev = 1.0, base score would be 0 (100 - 100*1.0)
      # Confidence should be low
      expect(result[:confidence_score]).to be >= 0
    end
  end

  # Helper methods

  def build_project(id:, health:)
    double('Project',
           id: id,
           health: health,
           current_state: :in_progress)
  end

  def build_repo_with_updates(updates_data)
    updates = updates_data.map do |data|
      HealthUpdate.new(
        project_id: data[:project_id],
        date: data[:date],
        health: data[:health],
        description: nil
      )
    end

    repo = double('HealthUpdateRepository')
    allow(repo).to receive(:all_for_project) do |project_id|
      updates.select { |u| u.project_id == project_id }
    end
    allow(repo).to receive(:latest_for_project) do |project_id|
      project_updates = updates.select { |u| u.project_id == project_id }
      project_updates.max_by(&:date)
    end
    repo
  end

  def monday_weeks_ago(n)
    today = Date.current
    most_recent_monday = today - ((today.wday - 1) % 7)
    most_recent_monday -= 7 if most_recent_monday >= today
    most_recent_monday - ((n - 1) * 7)
  end
end
