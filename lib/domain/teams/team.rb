require_relative '../support/health_rollup'

class Team
  attr_reader :name, :mission, :vision, :point_of_contact

  def initialize(
    name:,
    mission: '',
    vision: '',
    point_of_contact: '',
    archived: false,
    owned_projects_loader: nil,
    subordinate_teams_loader: nil,
    parent_team_loader: nil
  )
    @name = name.to_s
    @mission = mission.to_s
    @vision = vision.to_s
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
    HealthRollup.rollup(all_leaf_projects)
  end

  def health_raw_score
    HealthRollup.raw_score(all_leaf_projects)
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
    return point_of_contact if point_of_contact.present?
    return parent_team.effective_contact if parent_team

    nil
  end

  private

  attr_reader :owned_projects_loader, :subordinate_teams_loader, :parent_team_loader

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
