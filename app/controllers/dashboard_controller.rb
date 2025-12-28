class DashboardController < ApplicationController
  include ApplicationHelper

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
    @sorted_all_projects = sort_projects_canonical(@all_projects)
    @sorted_attention_required = sort_projects_canonical(@attention_required)
    @sorted_never_updated_projects = sort_projects_canonical(@never_updated_projects)
    @sorted_stale_projects_14 = sort_projects_canonical(@stale_projects_14)
    @sorted_stale_projects_7 = sort_projects_canonical(@stale_projects_7)
    @sorted_active_projects = sort_projects_canonical(@active_projects)
    @sorted_inactive_projects = sort_projects_canonical(@inactive_projects)
    @sorted_orphan_projects = sort_projects_canonical(@orphan_projects)

    # Teams and initiatives for columns with trend/confidence data
    @teams = team_repository.all_active_roots
    @sorted_teams = sort_entities_by_health_name(@teams)
    @team_data = build_team_data(@teams)
    @archived_teams = team_repository.all_archived_roots
    @initiatives = initiative_repository.all_active_roots
    @sorted_initiatives = sort_entities_by_health_name(@initiatives)
    @initiative_data = build_initiative_data(@initiatives)
    @archived_initiatives = initiative_repository.all_archived

    # System-wide trend data
    trend_service = SystemTrendService.new(
      project_repository: project_repository,
      health_update_repository: health_update_repository,
      current_date: Date.current
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

    # Build presenters for shared partials
    build_metric_presenters
    build_search_data
    build_section_presenters
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

  HEALTH_SCORES = { on_track: 1, at_risk: 0, off_track: -1 }.freeze

  def calculate_system_health
    # Average teams and initiatives equally - each entity gets one vote
    health_values = []

    @teams.each do |team|
      health = team.health
      health_values << HEALTH_SCORES[health] if health != :not_available && HEALTH_SCORES.key?(health)
    end

    @initiatives.each do |initiative|
      health = initiative.health
      health_values << HEALTH_SCORES[health] if health != :not_available && HEALTH_SCORES.key?(health)
    end

    return :not_available if health_values.empty?

    average = health_values.sum(0.0) / health_values.length

    if average > 0.5
      :on_track
    elsif average <= -0.5
      :off_track
    else
      :at_risk
    end
  end

  def build_team_data(teams)
    teams.each_with_object({}) do |team, data|
      trend_service = TeamTrendService.new(
        team: team,
        health_update_repository: health_update_repository,
        current_date: Date.current
      )
      trend_result = trend_service.call

      leaf_projects = team.all_leaf_projects
      active_leaves = leaf_projects.select { |p| [:in_progress, :blocked].include?(p.current_state) }
      stale_count = active_leaves.count do |p|
        latest = p.latest_health_update
        latest.nil? || (Date.current - latest.date.to_date).to_i > 7
      end

      data[team.name] = {
        trend_direction: trend_result[:trend_direction],
        confidence_level: trend_result[:confidence_level],
        confidence_score: trend_result[:confidence_score],
        projects_count: leaf_projects.size,
        stale_count: stale_count
      }
    end
  end

  def build_initiative_data(initiatives)
    initiatives.each_with_object({}) do |initiative, data|
      trend_service = InitiativeTrendService.new(
        initiative: initiative,
        health_update_repository: health_update_repository,
        current_date: Date.current
      )
      trend_result = trend_service.call

      leaf_projects = initiative.leaf_projects
      active_leaves = leaf_projects.select { |p| [:in_progress, :blocked].include?(p.current_state) }
      stale_count = active_leaves.count do |p|
        latest = p.latest_health_update
        latest.nil? || (Date.current - latest.date.to_date).to_i > 7
      end

      data[initiative.name] = {
        trend_direction: trend_result[:trend_direction],
        confidence_level: trend_result[:confidence_level],
        confidence_score: trend_result[:confidence_score],
        projects_count: leaf_projects.size,
        stale_count: stale_count
      }
    end
  end

  def sort_entities_by_health_name(entities)
    health_order = { off_track: 0, at_risk: 1, not_available: 2, on_track: 3 }

    entities.sort_by do |entity|
      health = entity.health
      health_rank = health_order[health] || 99

      [health_rank, entity.name.to_s.downcase]
    end
  end

  def build_metric_presenters
    # Health presenter
    off_track_count = @teams.count { |t| t.health == :off_track } +
                      @initiatives.count { |i| i.health == :off_track }
    at_risk_count = @teams.count { |t| t.health == :at_risk } +
                    @initiatives.count { |i| i.health == :at_risk }
    total_count = @teams.size + @initiatives.size
    raw_score = calculate_raw_score

    @health_presenter = HealthPresenter.new(
      health: @system_health,
      raw_score: raw_score,
      off_track_count: off_track_count,
      at_risk_count: at_risk_count,
      total_count: total_count,
      methodology: "Average of team and initiative health scores, equally weighted."
    )

    # Trend presenter
    @trend_presenter = TrendPresenter.new(
      trend_data: @trend_data,
      trend_direction: @trend_direction,
      trend_delta: @trend_delta,
      weeks_of_data: @weeks_of_data,
      gradient_id: "dashboard-trend-gradient"
    )

    # Confidence presenter
    @confidence_presenter = ConfidencePresenter.new(
      score: @confidence_score,
      level: @confidence_level,
      factors: @confidence_factors
    )
  end

  def calculate_raw_score
    health_values = []
    @teams.each do |team|
      health = team.health
      health_values << HEALTH_SCORES[health] if health != :not_available && HEALTH_SCORES.key?(health)
    end
    @initiatives.each do |initiative|
      health = initiative.health
      health_values << HEALTH_SCORES[health] if health != :not_available && HEALTH_SCORES.key?(health)
    end
    health_values.any? ? health_values.sum(0.0) / health_values.length : nil
  end

  def build_search_data
    # Build flat list of all teams with ancestry for search
    @search_teams = []
    build_team_tree = ->(teams, ancestors = []) do
      teams.sort_by(&:name).each do |team|
        path = ancestors + [team.name]
        @search_teams << { entity: team }
        build_team_tree.call(team.subordinate_teams, path) if team.subordinate_teams.any?
      end
    end
    build_team_tree.call(@teams)

    # Build flat list of all initiatives
    @search_initiatives = @initiatives.map do |initiative|
      { entity: initiative }
    end

    # Build flat list of all projects
    @search_projects = @all_projects.map do |project|
      { entity: project }
    end
  end

  def build_section_presenters
    # Teams section (compact)
    @team_presenters = @sorted_teams.map do |team|
      team_info = @team_data[team.name] || {}
      TeamSectionCompactItemPresenter.new(
        entity: team,
        view_context: view_context,
        trend_direction: team_info[:trend_direction] || :stable,
        projects_count: team_info[:projects_count] || 0,
        stale_count: team_info[:stale_count] || 0
      )
    end

    @archived_team_presenters = @archived_teams.map do |team|
      TeamSectionCompactItemPresenter.new(
        entity: team,
        view_context: view_context
      )
    end

    # Initiatives section (compact)
    @initiative_presenters = @sorted_initiatives.map do |initiative|
      initiative_info = @initiative_data[initiative.name] || {}
      InitiativeSectionCompactItemPresenter.new(
        entity: initiative,
        view_context: view_context,
        trend_direction: initiative_info[:trend_direction] || :stable,
        projects_count: initiative_info[:projects_count] || 0,
        stale_count: initiative_info[:stale_count] || 0
      )
    end

    @archived_initiative_presenters = @archived_initiatives.map do |initiative|
      InitiativeSectionCompactItemPresenter.new(
        entity: initiative,
        view_context: view_context
      )
    end

  end
end
