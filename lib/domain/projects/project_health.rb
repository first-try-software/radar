require 'ostruct'
require_relative '../support/health_rollup'

# This class gathers scores from either a project's health updates or its children's health updates
# and returns the appropriate health characterization (on_track, at_risk, off_track). This class
# delegates the calculation of health to the HealthRollup class.

class ProjectHealth
  SCORES = { on_track: 1, at_risk: 0, off_track: -1 }.freeze

  def initialize(health_updates_loader:, weekly_health_updates_loader:, children_loader:, current_date: Date.today)
    @health_updates_loader = health_updates_loader
    @weekly_health_updates_loader = weekly_health_updates_loader
    @children_loader = children_loader
    @current_date = current_date
  end

  def health
    return subordinate_health if children.any?
    return :not_available if health_updates.empty?

    latest_health_update.health
  end

  def health_trend
    if children.any?
      children_weekly_rollups_with_current
    else
      weekly_health_updates_with_current
    end
  end

  def latest_health_update
    health_updates.last
  end

  def health_updates_for_tooltip
    return nil if children.any?

    health_updates
  end

  def children_health_for_tooltip
    return nil if children.empty?

    children.map do |child|
      OpenStruct.new(name: child.name, health: child.health)
    end
  end

  private

  attr_reader :health_updates_loader, :weekly_health_updates_loader, :children_loader

  def children
    @children ||= Array(children_loader&.call) || []
  end

  def health_updates
    @health_updates ||= Array(health_updates_loader&.call).reject { |u| future_date?(u.date) }
  end

  def weekly_health_updates
    @weekly_health_updates ||= Array(weekly_health_updates_loader&.call).reject { |u| future_date?(u.date) }
  end

  def future_date?(date)
    date.to_date > current_date
  end

  attr_reader :current_date

  def subordinate_health
    HealthRollup.health_from_projects(children)
  end

  def rollup_health_values(healths)
    healths = healths.reject { |h| h == :not_available }
    return :not_available if healths.empty?

    scores = healths.map { |h| SCORES[h] }.compact

    HealthRollup.health_from_scores(scores)
  end

  def weekly_health_updates_with_current
    historical = weekly_health_updates
    latest = health_updates.last
    current_health_value = latest ? latest.health : :not_available
    current_description = latest&.description
    current = OpenStruct.new(date: current_date, health: current_health_value, description: current_description)

    historical.last(6) + [current]
  end

  def children_weekly_rollups_with_current
    historical = children_weekly_rollups
    current = OpenStruct.new(date: current_date, health: subordinate_health)

    historical + [current]
  end

  def children_weekly_rollups
    child_trends = children.map(&:health_trend)
    return [] if child_trends.all?(&:empty?)

    mondays_from_children = child_trends.flat_map { |trend| trend.map(&:date) }
                                        .uniq
                                        .reject { |d| future_date?(d) }
                                        .sort
    return [] if mondays_from_children.empty?

    mondays_from_children.last(6).map do |monday|
      child_healths = child_trends.map do |trend|
        monday_update = trend.find { |u| u.date == monday }
        monday_update&.health
      end.compact.reject { |h| h == :not_available }

      rolled_health = rollup_health_values(child_healths)

      OpenStruct.new(date: monday, health: rolled_health)
    end
  end
end
