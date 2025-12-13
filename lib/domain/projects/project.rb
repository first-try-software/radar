require 'ostruct'
require_relative '../support/health_rollup'

class Project
  ALLOWED_STATES = [:new, :todo, :in_progress, :blocked, :on_hold, :done].freeze

  attr_reader :name, :description, :point_of_contact, :current_state

  def initialize(
    name:,
    description: '',
    point_of_contact: '',
    archived: false,
    children_loader: nil,
    parent_loader: nil,
    health_updates_loader: nil,
    weekly_health_updates_loader: nil,
    current_state: :new
  )
    @name = name.to_s
    @description = description.to_s
    @point_of_contact = point_of_contact.to_s
    @archived = archived
    @children_loader = children_loader
    @parent_loader = parent_loader
    @health_updates_loader = health_updates_loader
    @weekly_health_updates_loader = weekly_health_updates_loader
    @children = nil
    @parent = nil
    @health_updates = nil
    @weekly_health_updates = nil
    @current_state = (current_state || :new).to_sym
  end

  def valid?
    name_present? && state_valid?
  end

  def errors
    [].tap do |errs|
      errs << 'name must be present' unless name_present?
      errs << 'state must be valid' unless state_valid?
    end
  end

  def archived?
    !!archived
  end

  def children
    @children ||= load_children
  end

  def subordinate_projects
    children
  end

  def parent
    @parent ||= load_parent
  end

  def with_state(state:)
    self.class.new(
      name: name,
      description: description,
      point_of_contact: point_of_contact,
      archived: archived?,
      children_loader: children_loader,
      parent_loader: parent_loader,
      health_updates_loader: health_updates_loader,
      weekly_health_updates_loader: weekly_health_updates_loader,
      current_state: state
    )
  end

  def health
    return :not_available unless working_state?

    return subordinate_health unless subordinate_health == :not_available
    return :not_available if health_updates.empty?

    latest_health_update.health
  end

  def health_trend
    return [] unless working_state?

    if children.any?
      children_weekly_rollups_with_current
    else
      weekly_health_updates_with_current
    end
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

  attr_reader :archived, :children_loader, :parent_loader, :health_updates_loader, :weekly_health_updates_loader

  def load_children
    return [] unless children_loader

    children_loader.call(self)
  end

  def load_parent
    return nil unless parent_loader

    parent_loader.call(self)
  end

  def health_updates
    @health_updates ||= Array(health_updates_loader&.call(self)).reject { |u| future_date?(u.date) }
  end

  def weekly_health_updates
    @weekly_health_updates ||= Array(weekly_health_updates_loader&.call(self)).reject { |u| future_date?(u.date) }
  end

  def weekly_health_updates_with_current
    historical = weekly_health_updates
    latest = health_updates.last
    current_health_value = latest ? latest.health : :not_available
    current_description = latest&.description
    current = OpenStruct.new(date: current_date, health: current_health_value, description: current_description)

    # Keep last 6 historical items plus current (7 total)
    historical.last(6) + [current]
  end

  def future_date?(date)
    return false unless date.respond_to?(:to_date)

    date.to_date > current_date
  end

  def current_date
    # Use Date.current if available (Rails), otherwise Date.today
    Date.respond_to?(:current) ? Date.current : Date.today
  end

  def subordinate_health
    @subordinate_health ||= HealthRollup.rollup(subordinate_projects)
  end

  def children_weekly_rollups_with_current
    historical = children_weekly_rollups
    current = OpenStruct.new(date: current_date, health: subordinate_health)

    # Keep all 6 historical items plus current (7 total)
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
      end.compact

      rolled_health = HealthRollup.rollup(
        child_healths.map { |h| OpenStruct.new(current_state: :in_progress, health: h) }
      )

      OpenStruct.new(date: monday, health: rolled_health)
    end
  end

  def latest_health_update
    @latest_health_update ||= health_updates.last
  end

  def working_state?
    [:in_progress, :blocked].include?(current_state)
  end

  def name_present?
    !name.strip.empty?
  end

  def state_valid?
    ALLOWED_STATES.include?(current_state)
  end
end
