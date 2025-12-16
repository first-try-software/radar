class TeamDashboard
  HEALTH_SEVERITY = { off_track: 0, at_risk: 1, on_track: 2, not_available: 3 }.freeze

  def initialize(team:, health_update_repository: nil)
    @team = team
    @health_update_repository = health_update_repository
  end

  def health_summary
    projects = active_projects
    {
      on_track: projects.count { |p| p.health == :on_track },
      at_risk: projects.count { |p| p.health == :at_risk },
      off_track: projects.count { |p| p.health == :off_track }
    }
  end

  def total_active_projects
    active_projects.count
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

  def on_hold_projects
    all_leaf_projects.select { |p| p.current_state == :on_hold }
  end

  def never_updated_projects
    active_working_projects.select do |project|
      project.health == :not_available
    end
  end

  def stale_projects(days: 14)
    return [] unless health_update_repository

    cutoff = current_date - days

    active_working_projects.select do |project|
      project_id = project.id || project.name
      latest_update = health_update_repository.latest_for_project(project_id)
      next false if latest_update.nil?

      latest_update.date < cutoff
    end
  end

  def stale_projects_between(min_days:, max_days:)
    return [] unless health_update_repository

    min_cutoff = current_date - min_days
    max_cutoff = current_date - max_days

    active_working_projects.select do |project|
      project_id = project.id || project.name
      latest_update = health_update_repository.latest_for_project(project_id)
      next false if latest_update.nil?

      latest_update.date < min_cutoff && latest_update.date >= max_cutoff
    end
  end

  def current_date
    Date.respond_to?(:current) ? Date.current : Date.today
  end

  private

  attr_reader :team, :health_update_repository

  def all_leaf_projects
    @all_leaf_projects ||= team.all_leaf_projects.reject(&:archived?)
  end

  def active_projects
    @active_projects ||= all_leaf_projects.select { |p| [:in_progress, :blocked].include?(p.current_state) }
  end

  def active_working_projects
    active_projects
  end
end
