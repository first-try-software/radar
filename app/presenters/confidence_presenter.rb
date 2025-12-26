# frozen_string_literal: true

# Presenter for shared/_confidence_widget.html.erb
# Provides confidence metrics for Team, Initiative, or Project entities
class ConfidencePresenter
  RING_RADIUS = 18
  CIRCUMFERENCE = 2 * Math::PI * RING_RADIUS

  def initialize(score:, level:, factors:)
    @score = score || 0
    @level = level || :low
    @factors = factors || {}
  end

  attr_reader :score, :level, :factors

  # Display
  def level_label
    level.to_s.titleize
  end

  def level_css_class
    level.to_s
  end

  # Hint based on biggest drag factor
  def hint
    case factors[:biggest_drag]
    when :variance then "Volatile health trend"
    when :staleness then "Data growing stale"
    when :coverage then "Update coverage is uneven"
    when :insufficient_data then "Building history..."
    end
  end

  def show_hint?
    hint.present? && level != :high
  end

  # Ring SVG calculations
  def ring_circumference
    CIRCUMFERENCE.round(1)
  end

  def ring_offset
    offset = CIRCUMFERENCE - (score / 100.0 * CIRCUMFERENCE)
    offset.round(1)
  end
end
