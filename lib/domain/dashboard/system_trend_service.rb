require_relative '../projects/health_update'

class SystemTrendService
  SCORES = { on_track: 1, at_risk: 0, off_track: -1 }.freeze
  STALENESS_PENALTY_7_DAYS = 15
  STALENESS_PENALTY_14_DAYS = 30
  COVERAGE_PENALTY_75 = 10
  COVERAGE_PENALTY_50 = 25

  def initialize(project_repository:, health_update_repository:)
    @project_repository = project_repository
    @health_update_repository = health_update_repository
  end

  def call
    {
      trend_data: trend_data,
      trend_direction: trend_direction,
      trend_delta: trend_delta,
      weeks_of_data: weeks_of_data,
      confidence_score: confidence_score,
      confidence_level: confidence_level,
      confidence_factors: confidence_factors
    }
  end

  private

  attr_reader :project_repository, :health_update_repository

  def projects
    @projects ||= project_repository.all_active_roots.reject do |p|
      p.current_state == :done || p.current_state == :on_hold
    end
  end

  def trend_data
    @trend_data ||= calculate_trend_data
  end

  def calculate_trend_data
    return [] if projects.empty? || health_update_repository.nil?

    weekly_scores = {}

    projects.each do |project|
      updates = health_update_repository.all_for_project(project.id)
      updates.each do |update|
        week_start = week_start_for(update.date)
        weekly_scores[week_start] ||= []
        weekly_scores[week_start] << SCORES[update.health]
      end
    end

    weekly_scores
      .sort_by { |date, _| date }
      .last(6)
      .map do |date, scores|
        avg = scores.compact.sum(0.0) / scores.compact.length
        health = score_to_health(avg)
        { date: date, score: avg, health: health }
      end
  end

  def week_start_for(date)
    date = date.to_date
    date - ((date.wday - 1) % 7)
  end

  def score_to_health(score)
    if score >= 0.51
      :on_track
    elsif score <= -0.49
      :off_track
    else
      :at_risk
    end
  end

  def weeks_of_data
    trend_data.length
  end

  def trend_direction
    return :stable if trend_data.length < 2

    first_score = trend_data.first[:score]
    last_score = trend_data.last[:score]
    delta = last_score - first_score

    if delta > 0.1
      :up
    elsif delta < -0.1
      :down
    else
      :stable
    end
  end

  def trend_delta
    return 0.0 if trend_data.length < 2

    first_score = trend_data.first[:score]
    last_score = trend_data.last[:score]
    (last_score - first_score).round(2)
  end

  def confidence_score
    return 0 if projects.empty? || trend_data.empty?

    base_score = calculate_base_confidence
    staleness_penalty = calculate_staleness_penalty
    coverage_penalty = calculate_coverage_penalty

    [(base_score - staleness_penalty - coverage_penalty), 0].max.round
  end

  def calculate_base_confidence
    return 100 if trend_data.length < 2

    scores = trend_data.map { |d| d[:score] }
    mean = scores.sum(0.0) / scores.length

    # Calculate standard deviation
    variance = scores.map { |s| (s - mean) ** 2 }.sum(0.0) / scores.length
    std_dev = Math.sqrt(variance)

    # Convert std_dev to confidence (lower std_dev = higher confidence)
    [100 - (std_dev * 100), 0].max
  end

  def calculate_staleness_penalty
    days_since_update = (current_date - most_recent_update_date).to_i

    if days_since_update > 14
      STALENESS_PENALTY_14_DAYS
    elsif days_since_update > 7
      STALENESS_PENALTY_7_DAYS
    else
      0
    end
  end

  def calculate_coverage_penalty
    projects_with_recent_updates = projects.count do |project|
      latest = health_update_repository.latest_for_project(project.id)
      latest && (current_date - latest.date.to_date).to_i <= 14
    end

    coverage_ratio = projects_with_recent_updates.to_f / projects.length

    if coverage_ratio < 0.5
      COVERAGE_PENALTY_50
    elsif coverage_ratio < 0.75
      COVERAGE_PENALTY_75
    else
      0
    end
  end

  def most_recent_update_date
    @most_recent_update_date ||= begin
      dates = projects.filter_map do |project|
        latest = health_update_repository.latest_for_project(project.id)
        latest&.date&.to_date
      end
      dates.max
    end
  end

  def confidence_level
    score = confidence_score
    if score >= 70
      :high
    elsif score >= 40
      :medium
    else
      :low
    end
  end

  def confidence_factors
    return { biggest_drag: :insufficient_data, details: {} } if projects.empty? || trend_data.empty?

    base = calculate_base_confidence
    staleness = calculate_staleness_penalty
    coverage = calculate_coverage_penalty

    # Calculate variance penalty (100 - base score)
    variance_penalty = 100 - base

    # Determine coverage details
    projects_needing_update = projects.count do |project|
      latest = health_update_repository.latest_for_project(project.id)
      latest.nil? || (current_date - latest.date.to_date).to_i > 14
    end

    days_since = (current_date - most_recent_update_date).to_i

    # Determine biggest drag
    penalties = {
      variance: variance_penalty,
      staleness: staleness,
      coverage: coverage
    }
    biggest_drag = penalties.max_by { |_, v| v }.first
    biggest_drag = :none if penalties.values.all?(&:zero?)

    {
      biggest_drag: biggest_drag,
      details: {
        variance_penalty: variance_penalty.round,
        staleness_penalty: staleness,
        coverage_penalty: coverage,
        days_since_update: days_since,
        projects_needing_update: projects_needing_update
      }
    }
  end

  def current_date
    Date.current
  end
end
