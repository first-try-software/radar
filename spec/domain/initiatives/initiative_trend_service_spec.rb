require 'rails_helper'
require Rails.root.join('lib/domain/initiatives/initiative_trend_service')

RSpec.describe InitiativeTrendService do
  describe '#call' do
    it 'returns empty trend data when initiative has no projects' do
      initiative = build_initiative(projects: [])
      service = InitiativeTrendService.new(initiative: initiative, health_update_repository: nil)

      result = service.call

      expect(result[:trend_data]).to eq([])
      expect(result[:weeks_of_data]).to eq(0)
    end

    it 'returns trend data points for weeks with health updates' do
      project = build_project(id: 1, health: :on_track)
      initiative = build_initiative(projects: [project])
      repo = build_repo_with_updates([
        { project_id: 1, date: monday_weeks_ago(2), health: :at_risk },
        { project_id: 1, date: monday_weeks_ago(1), health: :on_track }
      ])
      service = InitiativeTrendService.new(initiative: initiative, health_update_repository: repo)

      result = service.call

      expect(result[:trend_data].length).to be >= 2
      expect(result[:weeks_of_data]).to be >= 2
    end

    it 'calculates weekly health scores from project updates' do
      project = build_project(id: 1, health: :on_track)
      initiative = build_initiative(projects: [project])
      repo = build_repo_with_updates([
        { project_id: 1, date: monday_weeks_ago(2), health: :off_track },
        { project_id: 1, date: monday_weeks_ago(1), health: :on_track }
      ])
      service = InitiativeTrendService.new(initiative: initiative, health_update_repository: repo)

      result = service.call
      scores = result[:trend_data].map { |d| d[:score] }

      expect(scores).to include(-1.0) # off_track week
      expect(scores).to include(1.0)  # on_track week
    end

    it 'aggregates health across multiple projects for each week' do
      project1 = build_project(id: 1, health: :on_track)
      project2 = build_project(id: 2, health: :on_track)
      initiative = build_initiative(projects: [project1, project2])
      repo = build_repo_with_updates([
        { project_id: 1, date: monday_weeks_ago(1), health: :on_track },
        { project_id: 2, date: monday_weeks_ago(1), health: :off_track }
      ])
      service = InitiativeTrendService.new(initiative: initiative, health_update_repository: repo)

      result = service.call
      week_data = result[:trend_data].find { |d| d[:date] == monday_weeks_ago(1) }

      expect(week_data[:score]).to eq(0.0) # average of 1 and -1
    end

    it 'only includes data points where we have actual updates' do
      project = build_project(id: 1, health: :on_track)
      initiative = build_initiative(projects: [project])
      repo = build_repo_with_updates([
        { project_id: 1, date: monday_weeks_ago(4), health: :at_risk },
        { project_id: 1, date: monday_weeks_ago(1), health: :on_track }
      ])
      service = InitiativeTrendService.new(initiative: initiative, health_update_repository: repo)

      result = service.call
      dates = result[:trend_data].map { |d| d[:date] }

      expect(dates).to include(monday_weeks_ago(4))
      expect(dates).to include(monday_weeks_ago(1))
      expect(dates).not_to include(monday_weeks_ago(3))
      expect(dates).not_to include(monday_weeks_ago(2))
    end
  end

  describe 'trend direction' do
    it 'returns :up when health is improving' do
      project = build_project(id: 1, health: :on_track)
      initiative = build_initiative(projects: [project])
      repo = build_repo_with_updates([
        { project_id: 1, date: monday_weeks_ago(3), health: :off_track },
        { project_id: 1, date: monday_weeks_ago(2), health: :at_risk },
        { project_id: 1, date: monday_weeks_ago(1), health: :on_track }
      ])
      service = InitiativeTrendService.new(initiative: initiative, health_update_repository: repo)

      result = service.call

      expect(result[:trend_direction]).to eq(:up)
    end

    it 'returns :down when health is declining' do
      project = build_project(id: 1, health: :off_track)
      initiative = build_initiative(projects: [project])
      repo = build_repo_with_updates([
        { project_id: 1, date: monday_weeks_ago(3), health: :on_track },
        { project_id: 1, date: monday_weeks_ago(2), health: :at_risk },
        { project_id: 1, date: monday_weeks_ago(1), health: :off_track }
      ])
      service = InitiativeTrendService.new(initiative: initiative, health_update_repository: repo)

      result = service.call

      expect(result[:trend_direction]).to eq(:down)
    end

    it 'returns :stable when health is unchanged' do
      project = build_project(id: 1, health: :on_track)
      initiative = build_initiative(projects: [project])
      repo = build_repo_with_updates([
        { project_id: 1, date: monday_weeks_ago(2), health: :on_track },
        { project_id: 1, date: monday_weeks_ago(1), health: :on_track }
      ])
      service = InitiativeTrendService.new(initiative: initiative, health_update_repository: repo)

      result = service.call

      expect(result[:trend_direction]).to eq(:stable)
    end

    it 'returns :stable when insufficient data' do
      project = build_project(id: 1, health: :on_track)
      initiative = build_initiative(projects: [project])
      repo = build_repo_with_updates([
        { project_id: 1, date: monday_weeks_ago(1), health: :on_track }
      ])
      service = InitiativeTrendService.new(initiative: initiative, health_update_repository: repo)

      result = service.call

      expect(result[:trend_direction]).to eq(:stable)
    end
  end

  describe 'trend delta' do
    it 'calculates positive delta for improving trend' do
      project = build_project(id: 1, health: :on_track)
      initiative = build_initiative(projects: [project])
      repo = build_repo_with_updates([
        { project_id: 1, date: monday_weeks_ago(2), health: :off_track },
        { project_id: 1, date: monday_weeks_ago(1), health: :on_track }
      ])
      service = InitiativeTrendService.new(initiative: initiative, health_update_repository: repo)

      result = service.call

      expect(result[:trend_delta]).to eq(2.0) # from -1 to 1
    end

    it 'calculates negative delta for declining trend' do
      project = build_project(id: 1, health: :off_track)
      initiative = build_initiative(projects: [project])
      repo = build_repo_with_updates([
        { project_id: 1, date: monday_weeks_ago(2), health: :on_track },
        { project_id: 1, date: monday_weeks_ago(1), health: :off_track }
      ])
      service = InitiativeTrendService.new(initiative: initiative, health_update_repository: repo)

      result = service.call

      expect(result[:trend_delta]).to eq(-2.0) # from 1 to -1
    end

    it 'returns zero delta when insufficient data' do
      initiative = build_initiative(projects: [])
      service = InitiativeTrendService.new(initiative: initiative, health_update_repository: nil)

      result = service.call

      expect(result[:trend_delta]).to eq(0.0)
    end
  end

  describe 'confidence calculation' do
    it 'returns high confidence for consistent, fresh data with good coverage' do
      project1 = build_project(id: 1, health: :on_track)
      project2 = build_project(id: 2, health: :on_track)
      initiative = build_initiative(projects: [project1, project2])
      repo = build_repo_with_updates([
        { project_id: 1, date: monday_weeks_ago(2), health: :on_track },
        { project_id: 1, date: monday_weeks_ago(1), health: :on_track },
        { project_id: 1, date: Date.current - 2, health: :on_track },
        { project_id: 2, date: monday_weeks_ago(2), health: :on_track },
        { project_id: 2, date: monday_weeks_ago(1), health: :on_track },
        { project_id: 2, date: Date.current - 2, health: :on_track }
      ])
      service = InitiativeTrendService.new(initiative: initiative, health_update_repository: repo)

      result = service.call

      expect(result[:confidence_level]).to eq(:high)
      expect(result[:confidence_score]).to be >= 70
    end

    it 'reduces confidence when data is stale (>14 days)' do
      project = build_project(id: 1, health: :on_track)
      initiative = build_initiative(projects: [project])
      repo = build_repo_with_updates([
        { project_id: 1, date: monday_weeks_ago(4), health: :on_track },
        { project_id: 1, date: monday_weeks_ago(3), health: :on_track }
      ])
      service = InitiativeTrendService.new(initiative: initiative, health_update_repository: repo)

      result = service.call

      expect(result[:confidence_score]).to be < 70
    end

    it 'reduces confidence when coverage is low' do
      project1 = build_project(id: 1, health: :on_track)
      project2 = build_project(id: 2, health: :not_available)
      project3 = build_project(id: 3, health: :not_available)
      project4 = build_project(id: 4, health: :not_available)
      project5 = build_project(id: 5, health: :not_available)
      initiative = build_initiative(projects: [project1, project2, project3, project4, project5])
      repo = build_repo_with_updates([
        { project_id: 1, date: Date.current - 2, health: :on_track }
      ])
      service = InitiativeTrendService.new(initiative: initiative, health_update_repository: repo)

      result = service.call

      # Only 1 of 5 projects (20%) has recent updates, should get 25% penalty
      expect(result[:confidence_score]).to be <= 75
    end

    it 'returns low confidence level when score is below 40' do
      project1 = build_project(id: 1, health: :on_track)
      project2 = build_project(id: 2, health: :not_available)
      project3 = build_project(id: 3, health: :not_available)
      project4 = build_project(id: 4, health: :not_available)
      initiative = build_initiative(projects: [project1, project2, project3, project4])
      # Stale data (>14 days = 30% penalty) + low coverage (<50% = 25% penalty) + volatile data
      repo = build_repo_with_updates([
        { project_id: 1, date: monday_weeks_ago(5), health: :on_track },
        { project_id: 1, date: monday_weeks_ago(4), health: :off_track },
        { project_id: 1, date: monday_weeks_ago(3), health: :on_track }
      ])
      service = InitiativeTrendService.new(initiative: initiative, health_update_repository: repo)

      result = service.call

      expect(result[:confidence_level]).to eq(:low)
      expect(result[:confidence_score]).to be < 40
    end

    it 'returns medium confidence level when score is between 40 and 69' do
      project = build_project(id: 1, health: :on_track)
      initiative = build_initiative(projects: [project])
      repo = build_repo_with_updates([
        { project_id: 1, date: monday_weeks_ago(2), health: :at_risk },
        { project_id: 1, date: monday_weeks_ago(1), health: :on_track },
        { project_id: 1, date: Date.current - 10, health: :on_track }
      ])
      service = InitiativeTrendService.new(initiative: initiative, health_update_repository: repo)

      result = service.call

      expect(result[:confidence_level]).to eq(:medium)
    end

    it 'returns zero confidence when no data' do
      initiative = build_initiative(projects: [])
      service = InitiativeTrendService.new(initiative: initiative, health_update_repository: nil)

      result = service.call

      expect(result[:confidence_score]).to eq(0)
      expect(result[:confidence_level]).to eq(:low)
    end

    it 'returns empty trend data when health_update_repository is nil but projects exist' do
      project = build_project(id: 1, health: :on_track)
      initiative = build_initiative(projects: [project])
      service = InitiativeTrendService.new(initiative: initiative, health_update_repository: nil)

      result = service.call

      expect(result[:trend_data]).to eq([])
      expect(result[:confidence_score]).to eq(0)
    end

    it 'applies medium coverage penalty when coverage is between 50% and 75%' do
      project1 = build_project(id: 1, health: :on_track)
      project2 = build_project(id: 2, health: :not_available)
      project3 = build_project(id: 3, health: :not_available)
      initiative = build_initiative(projects: [project1, project2, project3])
      # 2 of 3 projects (66%) have recent updates - should get 10% penalty (COVERAGE_PENALTY_75)
      repo = build_repo_with_updates([
        { project_id: 1, date: Date.current - 2, health: :on_track },
        { project_id: 2, date: Date.current - 2, health: :on_track }
      ])
      service = InitiativeTrendService.new(initiative: initiative, health_update_repository: repo)

      result = service.call

      # With 66% coverage (between 50% and 75%), should apply 10% penalty
      expect(result[:confidence_factors][:details][:coverage_penalty]).to eq(10)
    end

    it 'applies staleness penalty when data is 7-14 days old' do
      project = build_project(id: 1, health: :on_track)
      initiative = build_initiative(projects: [project])
      repo = build_repo_with_updates([
        { project_id: 1, date: monday_weeks_ago(3), health: :on_track },
        { project_id: 1, date: monday_weeks_ago(2), health: :on_track },
        { project_id: 1, date: Date.current - 10, health: :on_track }
      ])
      service = InitiativeTrendService.new(initiative: initiative, health_update_repository: repo)

      result = service.call

      expect(result[:confidence_factors][:details][:staleness_penalty]).to eq(15)
    end

    it 'reports no biggest drag when all penalties are zero' do
      project = build_project(id: 1, health: :on_track)
      initiative = build_initiative(projects: [project])
      repo = build_repo_with_updates([
        { project_id: 1, date: Date.current - 1, health: :on_track }
      ])
      service = InitiativeTrendService.new(initiative: initiative, health_update_repository: repo)

      result = service.call

      expect(result[:confidence_factors][:biggest_drag]).to eq(:none)
    end

    it 'handles projects with no health updates in most_recent_update_date' do
      project1 = build_project(id: 1, health: :on_track)
      project2 = build_project(id: 2, health: :not_available)
      initiative = build_initiative(projects: [project1, project2])
      # Only project1 has updates, project2 has none
      repo = build_repo_with_updates([
        { project_id: 1, date: monday_weeks_ago(2), health: :on_track },
        { project_id: 1, date: monday_weeks_ago(1), health: :on_track }
      ])
      service = InitiativeTrendService.new(initiative: initiative, health_update_repository: repo)

      result = service.call

      # Should still work, just ignoring the project without updates for date calculation
      expect(result[:trend_data].length).to be >= 2
      # project2 has no updates so it needs an update
      expect(result[:confidence_factors][:details][:projects_needing_update]).to eq(1)
    end

    it 'returns nil days_since_update when no projects have updates' do
      project = build_project(id: 1, health: :not_available)
      initiative = build_initiative(projects: [project])
      # No updates for this project
      repo = build_repo_with_updates([])
      service = InitiativeTrendService.new(initiative: initiative, health_update_repository: repo)

      result = service.call

      expect(result[:confidence_factors][:details][:days_since_update]).to be_nil
    end

    it 'counts project as needing update when latest update is more than 14 days old' do
      project1 = build_project(id: 1, health: :at_risk)
      project2 = build_project(id: 2, health: :on_track)
      initiative = build_initiative(projects: [project1, project2])
      # project1 has stale update (>14 days), project2 has recent update
      repo = build_repo_with_updates([
        { project_id: 1, date: monday_weeks_ago(3), health: :at_risk },
        { project_id: 1, date: monday_weeks_ago(4), health: :at_risk },
        { project_id: 2, date: Date.current - 2, health: :on_track },
        { project_id: 2, date: monday_weeks_ago(1), health: :on_track }
      ])
      service = InitiativeTrendService.new(initiative: initiative, health_update_repository: repo)

      result = service.call

      # project1 needs update (>14 days old), project2 does not (recent)
      expect(result[:confidence_factors][:details][:projects_needing_update]).to eq(1)
    end
  end

  # Helper methods

  def build_initiative(projects:)
    double('Initiative', leaf_projects: projects)
  end

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
