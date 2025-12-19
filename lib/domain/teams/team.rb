require_relative '../support/health_rollup'

class Team
  attr_reader :name, :description, :point_of_contact

  def initialize(
    name:,
    description: '',
    point_of_contact: '',
    archived: false,
    owned_projects_loader: nil,
    subordinate_teams_loader: nil,
    parent_team_loader: nil
  )
    @name = name.to_s
    @description = description.to_s
    @point_of_contact = point_of_contact.to_s
    @archived = archived
    @owned_projects_loader = owned_projects_loader
    @subordinate_teams_loader = subordinate_teams_loader
    @parent_team_loader = parent_team_loader
    @owned_projects = nil
    @subordinate_teams = nil
    @parent_team = nil
  end

  def valid?
    !name.strip.empty?
  end

  def errors
    return [] if valid?

    ['name must be present']
  end

  def archived?
    !!@archived
  end

  def owned_projects
    @owned_projects ||= load_owned_projects
  end

  def health
    health_values = collect_health_values
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

  def health_raw_score
    health_values = collect_health_values
    return nil if health_values.empty?

    health_values.sum(0.0) / health_values.length
  end

  def all_leaf_projects
    own_leaves = owned_projects.flat_map(&:leaf_descendants)
    subordinate_leaves = subordinate_teams.flat_map(&:all_leaf_projects)
    own_leaves + subordinate_leaves
  end

  def subordinate_teams
    @subordinate_teams ||= load_subordinate_teams
  end

  def parent_team
    @parent_team ||= load_parent_team
  end

  def effective_contact
    return point_of_contact if point_of_contact && !point_of_contact.strip.empty?
    return parent_team.effective_contact if parent_team

    nil
  end

  private

  HEALTH_SCORES = { on_track: 1, at_risk: 0, off_track: -1 }.freeze
  WORKING_STATES = [:in_progress, :blocked].freeze

  attr_reader :owned_projects_loader, :subordinate_teams_loader, :parent_team_loader

  def collect_health_values
    project_scores = owned_projects
      .select { |p| WORKING_STATES.include?(p.current_state) }
      .map { |p| HEALTH_SCORES[p.health] }
      .compact

    subordinate_scores = subordinate_teams
      .map(&:health)
      .reject { |h| h == :not_available }
      .map { |h| HEALTH_SCORES[h] }
      .compact

    project_scores + subordinate_scores
  end

  def load_owned_projects
    owned_projects_loader ? Array(owned_projects_loader.call(self)) : []
  end

  def load_subordinate_teams
    subordinate_teams_loader ? Array(subordinate_teams_loader.call(self)) : []
  end

  def load_parent_team
    parent_team_loader ? parent_team_loader.call(self) : nil
  end
end
