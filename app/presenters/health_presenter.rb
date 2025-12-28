# frozen_string_literal: true

# Presenter for shared/_health_widget.html.erb
# Provides health metrics for Team, Initiative, or Project entities
class HealthPresenter
  def initialize(health:, raw_score: nil, off_track_count: 0, at_risk_count: 0, total_count: 0, methodology: nil)
    @health = health || :not_available
    @raw_score = raw_score
    @off_track_count = off_track_count
    @at_risk_count = at_risk_count
    @total_count = total_count
    @methodology = methodology
  end

  # Health status
  def health
    @health
  end

  def health_css_class
    @health.to_s.tr("_", "-")
  end

  def health_label
    @health.to_s.tr("_", " ").titleize
  end

  # Score display
  def raw_score_display
    return "N/A" unless @raw_score

    if @raw_score >= 0
      "+#{@raw_score.round(2)}"
    else
      @raw_score.round(2).to_s
    end
  end

  # Counts
  attr_reader :off_track_count, :at_risk_count, :total_count

  def show_off_track_detail?
    off_track_count.positive?
  end

  def off_track_detail
    "#{off_track_count} of #{total_count} items off-track"
  end

  def show_at_risk_detail?
    !show_off_track_detail? && at_risk_count.positive?
  end

  def at_risk_detail
    "#{at_risk_count} of #{total_count} items at-risk"
  end

  # Methodology text for tooltip
  def methodology
    @methodology || "Weighted average of leaf project health scores."
  end
end
