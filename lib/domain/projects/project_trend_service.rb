require_relative 'health_update'

class ProjectTrendService
  SCORES = { on_track: 1, at_risk: 0, off_track: -1 }.freeze
  STALENESS_PENALTY_7_DAYS = 15
  STALENESS_PENALTY_14_DAYS = 30

  def initialize(project:, health_update_repository:)
    @project = project
    @health_update_repository = health_update_repository
  end

  def call
    {
      trend_data: trend_data,
      trend_direction: trend_direction,
      trend_delta: trend_delta,
      weeks_of_data: weeks_of_data,
      confidence_score: confidence_score,
      confidence_level: confidence_level
    }
  end

  private

  attr_reader :project, :health_update_repository

  def trend_data
    @trend_data ||= calculate_trend_data
  end

  def calculate_trend_data
    return [] if health_update_repository.nil?

    updates = health_update_repository.all_for_project(project.id)
    return [] if updates.empty?

    weekly_scores = {}

    updates.each do |update|
      week_start = week_start_for(update.date)
      weekly_scores[week_start] ||= []
      weekly_scores[week_start] << SCORES[update.health]
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
    return 0 if trend_data.empty?

    base_score = calculate_base_confidence
    staleness_penalty = calculate_staleness_penalty

    [(base_score - staleness_penalty), 0].max.round
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

  def most_recent_update_date
    @most_recent_update_date ||= begin
      latest = health_update_repository.latest_for_project(project.id)
      latest.date.to_date
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

  def current_date
    Date.current
  end
end
