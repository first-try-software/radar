require_relative '../support/health_rollup'
require_relative 'team_attributes'
require_relative 'team_loaders'

class Team
  def initialize(attributes:, loaders: TeamLoaders.new)
    @attributes = attributes
    @loaders = loaders
    @owned_projects = nil
    @subordinate_teams = nil
    @parent_team = nil
  end

  def id = attributes.id
  def name = attributes.name
  def description = attributes.description
  def point_of_contact = attributes.point_of_contact
  def archived? = attributes.archived?

  def valid?
    attributes.valid?
  end

  def errors
    attributes.errors
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

  attr_reader :attributes, :loaders

  def collect_health_values
    # Virtual child approach: local projects as a group get equal weight to each child team
    health_votes = []

    # Add local projects' aggregate health as one vote (if any are in working state)
    local_project_score = compute_local_projects_score
    health_votes << local_project_score unless local_project_score.nil?

    # Add each subordinate team's health as one vote
    subordinate_teams.each do |child_team|
      child_health = child_team.health
      next if child_health == :not_available

      health_votes << HEALTH_SCORES[child_health]
    end

    health_votes
  end

  def compute_local_projects_score
    working_projects = owned_projects.select { |p| WORKING_STATES.include?(p.current_state) }
    scores = working_projects.map { |p| HEALTH_SCORES[p.health] }.compact
    return nil if scores.empty?

    scores.sum(0.0) / scores.length
  end

  def load_owned_projects
    loaders.owned_projects ? Array(loaders.owned_projects.call(self)) : []
  end

  def load_subordinate_teams
    loaders.subordinate_teams ? Array(loaders.subordinate_teams.call(self)) : []
  end

  def load_parent_team
    loaders.parent_team ? loaders.parent_team.call(self) : nil
  end
end
