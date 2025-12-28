require 'ostruct'

class Dashboard
  HEALTH_SEVERITY = { off_track: 0, at_risk: 1, on_track: 2, not_available: 3 }.freeze

  def initialize(project_repository:, health_update_repository: nil, initiative_repository: nil, team_repository: nil)
    @project_repository = project_repository
    @health_update_repository = health_update_repository
    @initiative_repository = initiative_repository
    @team_repository = team_repository
  end

  def health_summary
    projects = active_root_projects
    {
      on_track: projects.count { |p| p.health == :on_track },
      at_risk: projects.count { |p| p.health == :at_risk },
      off_track: projects.count { |p| p.health == :off_track }
    }
  end

  def state_summary
    projects = active_root_projects
    {
      new: projects.count { |p| p.current_state == :new },
      todo: projects.count { |p| p.current_state == :todo },
      in_progress: projects.count { |p| p.current_state == :in_progress },
      on_hold: projects.count { |p| p.current_state == :on_hold },
      blocked: projects.count { |p| p.current_state == :blocked },
      done: projects.count { |p| p.current_state == :done }
    }
  end

  def total_active_projects
    active_root_projects.count
  end

  def attention_required
    projects = active_working_projects.select do |project|
      project.health == :off_track ||
        project.health == :at_risk ||
        project.current_state == :blocked
    end

    projects.sort_by do |p|
      [HEALTH_SEVERITY[p.health] || 99, p.name.downcase]
    end
  end

  def attention_required_initiatives
    return [] unless initiative_repository

    initiatives = active_initiatives.select do |initiative|
      initiative.health == :off_track ||
        initiative.health == :at_risk ||
        initiative.current_state == :blocked
    end

    initiatives.sort_by do |i|
      [HEALTH_SEVERITY[i.health] || 99, i.name.downcase]
    end
  end

  def attention_required_teams
    return [] unless team_repository

    teams = active_teams.select do |team|
      team.health == :off_track || team.health == :at_risk
    end

    teams.sort_by do |t|
      [HEALTH_SEVERITY[t.health] || 99, t.name.downcase]
    end
  end

  def recent_health_updates(limit: 10)
    return [] unless health_update_repository

    updates = health_update_repository.all
    sorted = updates.sort_by(&:date).reverse.first(limit)

    sorted.map do |update|
      project = project_repository.find(update.project_id)
      project_name = project&.name || 'Unknown'
      DashboardHealthUpdate.new(
        project_id: update.project_id,
        project_name: project_name,
        date: update.date,
        health: update.health,
        description: update.description
      )
    end
  end

  def stale_projects(days: 14)
    cutoff = current_date - days

    active_working_projects.select do |project|
      next false unless [:in_progress, :blocked].include?(project.current_state)
      project_id = project.id || project.name
      latest_update = health_update_repository&.latest_for_project(project_id)
      next false if latest_update.nil?

      latest_update.date < cutoff
    end
  end

  def stale_projects_between(min_days:, max_days:)
    min_cutoff = current_date - min_days
    max_cutoff = current_date - max_days

    active_working_projects.select do |project|
      next false unless [:in_progress, :blocked].include?(project.current_state)
      project_id = project.id || project.name
      latest_update = health_update_repository&.latest_for_project(project_id)
      next false if latest_update.nil?

      latest_update.date < min_cutoff && latest_update.date >= max_cutoff
    end
  end

  def never_updated_projects
    active_working_projects.select do |project|
      [:in_progress, :blocked].include?(project.current_state) && project.health == :not_available
    end
  end

  def on_hold_projects
    active_root_projects.select { |p| p.current_state == :on_hold }
  end

  def orphan_projects
    project_repository.orphan_projects.reject do |p|
      p.current_state == :done || p.current_state == :on_hold
    end
  end

  def current_date
    Date.today
  end

  private

  attr_reader :project_repository, :health_update_repository, :initiative_repository, :team_repository

  def active_root_projects
    project_repository.all_active_roots
  end

  def active_working_projects
    active_root_projects.reject { |p| p.current_state == :done || p.current_state == :on_hold }
  end

  def active_initiatives
    initiative_repository.all_active_roots.reject { |i| i.current_state == :done }
  end

  def active_teams
    team_repository.all_active_roots
  end

  class DashboardHealthUpdate
    attr_reader :project_id, :project_name, :date, :health, :description

    def initialize(project_id:, project_name:, date:, health:, description:)
      @project_id = project_id
      @project_name = project_name
      @date = date
      @health = health
      @description = description
    end
  end
end
