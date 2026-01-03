class HealthRollup
  SCORES = { on_track: 1, at_risk: 0, off_track: -1 }.freeze
  THRESHOLDS = { on_track: 0.5, off_track: -0.5 }.freeze
  ACTIVE_STATES = [:in_progress, :blocked].freeze

  def self.health_from_projects(projects)
    actual_scores = scores_from_projects(projects)
    health_from_scores(actual_scores)
  end

  def self.health_from_scores(scores)
    actual_scores = Array(scores).compact
    return :not_available if actual_scores.empty?

    health_from_score(average(actual_scores))
  end

  def self.health_from_score(score)
    if score > THRESHOLDS[:on_track]
      :on_track
    elsif score <= THRESHOLDS[:off_track]
      :off_track
    else
      :at_risk
    end
  end

  def self.scores_from_projects(projects)
    active_projects = Array(projects)
      .reject(&:archived?)
      .select { |project| ACTIVE_STATES.include?(project.current_state) }

    active_projects.map { |project| SCORES[project.health] }.compact
  end

  def self.score_from_projects(projects)
    actual_scores = scores_from_projects(projects)
    average(actual_scores)
  end

  def self.average(scores)
    actual_scores = Array(scores).compact
    return nil if actual_scores.empty?

    actual_scores.sum(0.0) / actual_scores.length
  end
end
