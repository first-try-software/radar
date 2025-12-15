class DashboardController < ApplicationController
  def index
    @health_summary = dashboard.health_summary
    @total_active_projects = dashboard.total_active_projects
    @attention_required = dashboard.attention_required
    @attention_required_initiatives = dashboard.attention_required_initiatives
    @attention_required_teams = dashboard.attention_required_teams
    @on_hold_projects = dashboard.on_hold_projects
    @never_updated_projects = dashboard.never_updated_projects
    @stale_projects_14 = dashboard.stale_projects(days: 14)
    @stale_projects_7 = dashboard.stale_projects_between(min_days: 7, max_days: 14)
    @orphan_projects = dashboard.orphan_projects
  end

  private

  def dashboard
    Rails.application.config.x.dashboard
  end
end
