# frozen_string_literal: true

# Presenter for shared/_trend_widget.html.erb
# Provides 6-week trend data for Team, Initiative, or Project entities
class TrendPresenter
  def initialize(trend_data:, trend_direction:, trend_delta:, weeks_of_data:, gradient_id: "trend-gradient")
    @trend_data = trend_data || []
    @trend_direction = trend_direction || :stable
    @trend_delta = trend_delta || 0.0
    @weeks_of_data = weeks_of_data || 0
    @gradient_id = gradient_id
  end

  attr_reader :trend_data, :trend_direction, :trend_delta, :weeks_of_data, :gradient_id

  # CSS class based on trend
  def trend_css_class
    sufficient_data? ? "trend-#{trend_direction}" : "trend-insufficient"
  end

  # Delta display
  def delta_display
    prefix = trend_delta >= 0 ? "+" : ""
    "#{prefix}#{trend_delta.round(2)}"
  end

  def delta_summary
    "#{delta_display} (#{weeks_of_data} weeks)"
  end

  # Data availability
  def sufficient_data?
    weeks_of_data >= 2
  end

  def single_week?
    weeks_of_data == 1
  end

  def no_data?
    weeks_of_data < 1
  end

  def no_data_message
    if single_week?
      "1 week of data"
    else
      "Insufficient data"
    end
  end

  # SVG chart data
  def gradient_stops
    trend_data.each_with_index.map do |point, i|
      offset = (i.to_f / [trend_data.length - 1, 1].max * 100).round
      color = color_for_health(point[:health])
      { offset: offset, color: color }
    end
  end

  def chart_points
    trend_data.each_with_index.map do |point, i|
      x = (i.to_f / [trend_data.length - 1, 1].max * 180) + 10
      y = 45 - ((point[:score] + 1) / 2.0 * 40)
      { x: x.round(1), y: y.round(1), health: point[:health] }
    end
  end

  def polyline_points
    chart_points.map { |p| "#{p[:x]},#{p[:y]}" }.join(" ")
  end

  private

  def color_for_health(health)
    case health
    when :on_track then "#22c55e"
    when :off_track then "#ef4444"
    else "#f59e0b"
    end
  end
end
