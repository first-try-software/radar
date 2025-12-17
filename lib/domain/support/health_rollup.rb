class HealthRollup
  WORKING_STATES = [:in_progress, :blocked].freeze
  SCORES = { on_track: 1, at_risk: 0, off_track: -1 }.freeze

  def self.rollup(projects)
    average = raw_score(projects)
    return :not_available if average.nil?

    if average > 0.5
      :on_track
    elsif average <= -0.5
      :off_track
    else
      :at_risk
    end
  end

  def self.raw_score(projects)
    working_projects = Array(projects).select { |project| WORKING_STATES.include?(project.current_state) }
    scores = working_projects.map { |project| SCORES[project.health] }.compact
    return nil if scores.empty?

    scores.sum(0.0) / scores.length
  end
end
