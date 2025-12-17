class DashboardController < ApplicationController
  def index
    @health_summary = dashboard.health_summary
    @total_active_projects = dashboard.total_active_projects
    @total_projects = project_repository.all_active_roots.size
    @attention_required = dashboard.attention_required
    @attention_required_initiatives = dashboard.attention_required_initiatives
    @attention_required_teams = dashboard.attention_required_teams
    @on_hold_projects = dashboard.on_hold_projects
    @never_updated_projects = dashboard.never_updated_projects
    @stale_projects_14 = dashboard.stale_projects(days: 14)
    @stale_projects_7 = dashboard.stale_projects_between(min_days: 7, max_days: 14)
    @orphan_projects = dashboard.orphan_projects

    # Active and inactive project lists for tabs
    all_root_projects = project_repository.all_active_roots
    @active_projects = all_root_projects.select { |p| [:in_progress, :blocked].include?(p.current_state) }
    @inactive_projects = all_root_projects.reject { |p| [:in_progress, :blocked].include?(p.current_state) }

    # All projects for global search
    @all_projects = all_root_projects

    # Teams and initiatives for columns with trend/confidence data
    @teams = team_repository.all_active_roots
    @team_data = build_team_data(@teams)
    @initiatives = initiative_repository.all_active_roots
    @initiative_data = build_initiative_data(@initiatives)

    # System-wide trend data
    trend_service = SystemTrendService.new(
      project_repository: project_repository,
      health_update_repository: health_update_repository
    )
    trend_result = trend_service.call

    @trend_data = trend_result[:trend_data]
    @trend_direction = trend_result[:trend_direction]
    @trend_delta = trend_result[:trend_delta]
    @weeks_of_data = trend_result[:weeks_of_data]
    @confidence_score = trend_result[:confidence_score]
    @confidence_level = trend_result[:confidence_level]
    @confidence_factors = trend_result[:confidence_factors]

    # System health (aggregate of all active root projects)
    @system_health = calculate_system_health
  end

  private

  def dashboard
    Rails.application.config.x.dashboard
  end

  def project_repository
    Rails.application.config.x.project_repository
  end

  def health_update_repository
    Rails.application.config.x.health_update_repository
  end

  def team_repository
    Rails.application.config.x.team_repository
  end

  def initiative_repository
    Rails.application.config.x.initiative_repository
  end

  def calculate_system_health
    summary = @health_summary
    total = summary[:on_track] + summary[:at_risk] + summary[:off_track]
    return :not_available if total.zero?

    # Calculate weighted score: on_track=1, at_risk=0, off_track=-1
    score = (summary[:on_track] * 1 + summary[:at_risk] * 0 + summary[:off_track] * -1).to_f / total

    if score >= 0.51
      :on_track
    elsif score <= -0.49
      :off_track
    else
      :at_risk
    end
  end

  def build_team_data(teams)
    teams.each_with_object({}) do |team, data|
      trend_service = TeamTrendService.new(
        team: team,
        health_update_repository: health_update_repository
      )
      trend_result = trend_service.call

      data[team.name] = {
        trend_direction: trend_result[:trend_direction],
        confidence_level: trend_result[:confidence_level],
        confidence_score: trend_result[:confidence_score]
      }
    end
  end

  def build_initiative_data(initiatives)
    initiatives.each_with_object({}) do |initiative, data|
      trend_service = InitiativeTrendService.new(
        initiative: initiative,
        health_update_repository: health_update_repository
      )
      trend_result = trend_service.call

      data[initiative.name] = {
        trend_direction: trend_result[:trend_direction],
        confidence_level: trend_result[:confidence_level],
        confidence_score: trend_result[:confidence_score]
      }
    end
  end
end
