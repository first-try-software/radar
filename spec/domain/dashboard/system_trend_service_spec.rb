require 'rails_helper'

RSpec.describe SystemTrendService do
  let(:project_repository) { Rails.application.config.x.project_repository }
  let(:health_update_repository) { Rails.application.config.x.health_update_repository }

  def create_project(name, state: 'in_progress')
    ProjectRecord.create!(name: name, current_state: state)
  end

  def create_health_update(project, health:, date: Date.current)
    HealthUpdateRecord.create!(project: project, health: health, date: date)
  end

  describe '#call' do
    it 'returns trend data structure' do
      service = SystemTrendService.new(
        project_repository: project_repository,
        health_update_repository: health_update_repository
      )

      result = service.call

      expect(result).to have_key(:trend_data)
      expect(result).to have_key(:trend_direction)
      expect(result).to have_key(:trend_delta)
      expect(result).to have_key(:weeks_of_data)
      expect(result).to have_key(:confidence_score)
      expect(result).to have_key(:confidence_level)
      expect(result).to have_key(:confidence_factors)
    end

    it 'returns empty trend data when no projects exist' do
      service = SystemTrendService.new(
        project_repository: project_repository,
        health_update_repository: health_update_repository
      )

      result = service.call

      expect(result[:trend_data]).to eq([])
      expect(result[:weeks_of_data]).to eq(0)
    end

    it 'returns empty trend data when projects have no health updates' do
      create_project('Project A')

      service = SystemTrendService.new(
        project_repository: project_repository,
        health_update_repository: health_update_repository
      )

      result = service.call

      expect(result[:trend_data]).to eq([])
    end

    it 'calculates weekly averages across all active projects' do
      project_a = create_project('Project A')
      project_b = create_project('Project B')
      create_health_update(project_a, health: 'on_track', date: Date.current)
      create_health_update(project_b, health: 'off_track', date: Date.current)

      service = SystemTrendService.new(
        project_repository: project_repository,
        health_update_repository: health_update_repository
      )

      result = service.call

      expect(result[:weeks_of_data]).to eq(1)
      expect(result[:trend_data].first[:score]).to eq(0.0) # average of 1 and -1
    end

    it 'excludes done projects from trend calculation' do
      active_project = create_project('Active Project')
      _done_project = create_project('Done Project', state: 'done')
      create_health_update(active_project, health: 'on_track', date: Date.current)

      service = SystemTrendService.new(
        project_repository: project_repository,
        health_update_repository: health_update_repository
      )

      result = service.call

      expect(result[:weeks_of_data]).to eq(1)
      expect(result[:trend_data].first[:score]).to eq(1.0)
    end

    it 'excludes on_hold projects from trend calculation' do
      active_project = create_project('Active Project')
      _on_hold_project = create_project('On Hold Project', state: 'on_hold')
      create_health_update(active_project, health: 'off_track', date: Date.current)

      service = SystemTrendService.new(
        project_repository: project_repository,
        health_update_repository: health_update_repository
      )

      result = service.call

      expect(result[:trend_data].first[:score]).to eq(-1.0)
    end

    it 'limits trend data to 6 weeks' do
      project = create_project('Project')
      8.times do |i|
        create_health_update(project, health: 'on_track', date: Date.current - (i * 7))
      end

      service = SystemTrendService.new(
        project_repository: project_repository,
        health_update_repository: health_update_repository
      )

      result = service.call

      expect(result[:weeks_of_data]).to eq(6)
    end
  end

  describe 'trend direction' do
    it 'returns :stable when less than 2 weeks of data' do
      project = create_project('Project')
      create_health_update(project, health: 'on_track', date: Date.current)

      service = SystemTrendService.new(
        project_repository: project_repository,
        health_update_repository: health_update_repository
      )

      result = service.call

      expect(result[:trend_direction]).to eq(:stable)
    end

    it 'returns :up when health improves significantly' do
      project = create_project('Project')
      create_health_update(project, health: 'off_track', date: Date.current - 14)
      create_health_update(project, health: 'on_track', date: Date.current)

      service = SystemTrendService.new(
        project_repository: project_repository,
        health_update_repository: health_update_repository
      )

      result = service.call

      expect(result[:trend_direction]).to eq(:up)
    end

    it 'returns :down when health degrades significantly' do
      project = create_project('Project')
      create_health_update(project, health: 'on_track', date: Date.current - 14)
      create_health_update(project, health: 'off_track', date: Date.current)

      service = SystemTrendService.new(
        project_repository: project_repository,
        health_update_repository: health_update_repository
      )

      result = service.call

      expect(result[:trend_direction]).to eq(:down)
    end

    it 'returns :stable when change is small' do
      project = create_project('Project')
      create_health_update(project, health: 'at_risk', date: Date.current - 14)
      create_health_update(project, health: 'at_risk', date: Date.current)

      service = SystemTrendService.new(
        project_repository: project_repository,
        health_update_repository: health_update_repository
      )

      result = service.call

      expect(result[:trend_direction]).to eq(:stable)
    end
  end

  describe 'trend delta' do
    it 'returns 0.0 when less than 2 weeks of data' do
      project = create_project('Project')
      create_health_update(project, health: 'on_track', date: Date.current)

      service = SystemTrendService.new(
        project_repository: project_repository,
        health_update_repository: health_update_repository
      )

      result = service.call

      expect(result[:trend_delta]).to eq(0.0)
    end

    it 'calculates positive delta when improving' do
      project = create_project('Project')
      create_health_update(project, health: 'off_track', date: Date.current - 14)
      create_health_update(project, health: 'on_track', date: Date.current)

      service = SystemTrendService.new(
        project_repository: project_repository,
        health_update_repository: health_update_repository
      )

      result = service.call

      expect(result[:trend_delta]).to eq(2.0)
    end

    it 'calculates negative delta when declining' do
      project = create_project('Project')
      create_health_update(project, health: 'on_track', date: Date.current - 14)
      create_health_update(project, health: 'off_track', date: Date.current)

      service = SystemTrendService.new(
        project_repository: project_repository,
        health_update_repository: health_update_repository
      )

      result = service.call

      expect(result[:trend_delta]).to eq(-2.0)
    end
  end

  describe 'confidence score' do
    it 'returns 0 when no projects exist' do
      service = SystemTrendService.new(
        project_repository: project_repository,
        health_update_repository: health_update_repository
      )

      result = service.call

      expect(result[:confidence_score]).to eq(0)
    end

    it 'returns 0 when no trend data exists' do
      create_project('Project')

      service = SystemTrendService.new(
        project_repository: project_repository,
        health_update_repository: health_update_repository
      )

      result = service.call

      expect(result[:confidence_score]).to eq(0)
    end

    it 'returns high confidence with consistent recent data' do
      project = create_project('Project')
      3.times do |i|
        create_health_update(project, health: 'on_track', date: Date.current - (i * 7))
      end

      service = SystemTrendService.new(
        project_repository: project_repository,
        health_update_repository: health_update_repository
      )

      result = service.call

      expect(result[:confidence_score]).to be >= 70
      expect(result[:confidence_level]).to eq(:high)
    end

    it 'applies staleness penalty for data older than 7 days' do
      project = create_project('Project')
      create_health_update(project, health: 'on_track', date: Date.current - 10)
      create_health_update(project, health: 'on_track', date: Date.current - 17)

      service = SystemTrendService.new(
        project_repository: project_repository,
        health_update_repository: health_update_repository
      )

      result = service.call

      expect(result[:confidence_score]).to be < 100
    end

    it 'applies staleness penalty for data older than 14 days' do
      project = create_project('Project')
      create_health_update(project, health: 'on_track', date: Date.current - 20)
      create_health_update(project, health: 'on_track', date: Date.current - 27)

      service = SystemTrendService.new(
        project_repository: project_repository,
        health_update_repository: health_update_repository
      )

      result = service.call

      expect(result[:confidence_score]).to be < 70
    end

    it 'applies coverage penalty when less than 75% of projects have recent updates' do
      project_a = create_project('Project A')
      create_project('Project B')
      create_project('Project C')
      create_project('Project D')
      create_health_update(project_a, health: 'on_track', date: Date.current)

      service = SystemTrendService.new(
        project_repository: project_repository,
        health_update_repository: health_update_repository
      )

      result = service.call

      expect(result[:confidence_factors][:details][:coverage_penalty]).to be > 0
    end

    it 'applies medium coverage penalty when between 50% and 75% of projects have recent updates' do
      # 2 out of 3 projects = 66.7% coverage (between 50% and 75%)
      project_a = create_project('Project A')
      project_b = create_project('Project B')
      create_project('Project C')
      create_health_update(project_a, health: 'on_track', date: Date.current)
      create_health_update(project_b, health: 'on_track', date: Date.current)

      service = SystemTrendService.new(
        project_repository: project_repository,
        health_update_repository: health_update_repository
      )

      result = service.call

      expect(result[:confidence_factors][:details][:coverage_penalty]).to eq(10) # COVERAGE_PENALTY_75
    end
  end

  describe 'confidence level' do
    it 'returns :low when score is below 40' do
      create_project('Project')

      service = SystemTrendService.new(
        project_repository: project_repository,
        health_update_repository: health_update_repository
      )

      result = service.call

      expect(result[:confidence_level]).to eq(:low)
    end

    it 'returns :medium when score is between 40 and 70' do
      # Create 4 projects but only update 1 to get coverage penalty
      project_a = create_project('Project A')
      create_project('Project B')
      create_project('Project C')
      create_project('Project D')
      create_health_update(project_a, health: 'on_track', date: Date.current - 20)
      create_health_update(project_a, health: 'on_track', date: Date.current - 27)

      service = SystemTrendService.new(
        project_repository: project_repository,
        health_update_repository: health_update_repository
      )

      result = service.call

      expect(result[:confidence_level]).to eq(:medium)
    end
  end

  describe 'confidence factors' do
    it 'returns insufficient_data when no projects' do
      service = SystemTrendService.new(
        project_repository: project_repository,
        health_update_repository: health_update_repository
      )

      result = service.call

      expect(result[:confidence_factors][:biggest_drag]).to eq(:insufficient_data)
    end

    it 'returns insufficient_data when no trend data' do
      create_project('Project')

      service = SystemTrendService.new(
        project_repository: project_repository,
        health_update_repository: health_update_repository
      )

      result = service.call

      expect(result[:confidence_factors][:biggest_drag]).to eq(:insufficient_data)
    end

    it 'identifies staleness as biggest drag when applicable' do
      project = create_project('Project')
      create_health_update(project, health: 'on_track', date: Date.current - 20)
      create_health_update(project, health: 'on_track', date: Date.current - 27)

      service = SystemTrendService.new(
        project_repository: project_repository,
        health_update_repository: health_update_repository
      )

      result = service.call

      expect(result[:confidence_factors][:biggest_drag]).to eq(:staleness)
    end

    it 'identifies coverage as biggest drag when applicable' do
      project_a = create_project('Project A')
      create_project('Project B')
      create_project('Project C')
      create_health_update(project_a, health: 'on_track', date: Date.current)

      service = SystemTrendService.new(
        project_repository: project_repository,
        health_update_repository: health_update_repository
      )

      result = service.call

      expect(result[:confidence_factors][:biggest_drag]).to eq(:coverage)
    end

    it 'identifies variance as biggest drag when trend is volatile' do
      project = create_project('Project')
      create_health_update(project, health: 'on_track', date: Date.current)
      create_health_update(project, health: 'off_track', date: Date.current - 7)
      create_health_update(project, health: 'on_track', date: Date.current - 14)

      service = SystemTrendService.new(
        project_repository: project_repository,
        health_update_repository: health_update_repository
      )

      result = service.call

      expect(result[:confidence_factors][:biggest_drag]).to eq(:variance)
    end

    it 'returns :none when all penalties are zero' do
      project = create_project('Project')
      3.times do |i|
        create_health_update(project, health: 'on_track', date: Date.current - (i * 7))
      end

      service = SystemTrendService.new(
        project_repository: project_repository,
        health_update_repository: health_update_repository
      )

      result = service.call

      expect(result[:confidence_factors][:biggest_drag]).to eq(:none)
    end
  end
end
