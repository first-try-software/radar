require_relative '../support/health_rollup'

class Project
  ALLOWED_STATES = [:new, :todo, :in_progress, :blocked, :on_hold, :done].freeze

  attr_reader :name, :description, :point_of_contact, :current_state

  def initialize(
    name:,
    description: '',
    point_of_contact: '',
    archived: false,
    subordinates_loader: nil,
    health_updates_loader: nil,
    weekly_health_updates_loader: nil,
    current_state: :new
  )
    @name = name.to_s
    @description = description.to_s
    @point_of_contact = point_of_contact.to_s
    @archived = archived
    @subordinates_loader = subordinates_loader
    @health_updates_loader = health_updates_loader
    @weekly_health_updates_loader = weekly_health_updates_loader
    @subordinate_projects = nil
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

  def subordinate_projects
    @subordinate_projects ||= load_subordinates
  end

  def with_state(state:)
    self.class.new(
      name: name,
      description: description,
      point_of_contact: point_of_contact,
      archived: archived?,
      subordinates_loader: subordinates_loader,
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
    return [] if weekly_health_updates.empty?

    weekly_health_updates.last(6)
  end

  private

  attr_reader :archived, :subordinates_loader, :health_updates_loader, :weekly_health_updates_loader

  def load_subordinates
    return [] unless subordinates_loader

    subordinates_loader.call(self)
  end

  def health_updates
    @health_updates ||= Array(health_updates_loader&.call(self))
  end

  def weekly_health_updates
    @weekly_health_updates ||= Array(weekly_health_updates_loader&.call(self))
  end

  def subordinate_health
    @subordinate_health ||= HealthRollup.rollup(subordinate_projects)
  end

  def latest_health_update
    @latest_health_update ||= health_updates.max_by(&:date)
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
