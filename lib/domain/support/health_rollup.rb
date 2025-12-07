class HealthRollup
  WORKING_STATES = [:in_progress, :blocked].freeze
  SCORES = { on_track: 1, at_risk: 0, off_track: -1 }.freeze

  def self.rollup(projects)
    working_projects = Array(projects).select { |project| WORKING_STATES.include?(project.current_state) }
    scores = working_projects.map { |project| SCORES[project.health] }.compact
    return :not_available if scores.empty?

    average = scores.sum(0.0) / scores.length
    case average.round(0)
    when 1
      :on_track
    when -1
      :off_track
    else
      :at_risk
    end
  end
end
