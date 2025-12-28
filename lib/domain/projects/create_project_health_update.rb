require 'date'
require_relative '../support/result'
require_relative 'health_update'

class CreateProjectHealthUpdate
  ALLOWED_HEALTHS = [:on_track, :at_risk, :off_track].freeze

  def initialize(project_repository:, health_update_repository:, current_date: Date.today)
    @project_repository = project_repository
    @health_update_repository = health_update_repository
    @current_date = current_date
  end

  def perform(project_id:, date:, health:, description: nil)
    @project_id = project_id
    @date = date
    @health = health&.to_sym
    @description = description

    return project_not_found_failure unless project
    return not_a_leaf_failure unless project.leaf?
    return missing_date_failure unless date_present?
    return future_date_failure if future_date?
    return invalid_health_failure unless allowed_health?

    save
    success
  end

  private

  attr_reader :project_repository, :health_update_repository, :current_date, :project_id, :date, :health, :description

  def project
    @project ||= project_repository.find(project_id)
  end

  def allowed_health?
    ALLOWED_HEALTHS.include?(health)
  end

  def date_present?
    !date.nil?
  end

  def future_date?
    date.to_date > current_date
  end

  def project_not_found_failure
    failure('project not found')
  end

  def not_a_leaf_failure
    failure('health updates can only be created for leaf projects')
  end

  def missing_date_failure
    failure('date is required')
  end

  def future_date_failure
    failure('date cannot be in the future')
  end

  def invalid_health_failure
    failure('invalid health')
  end

  def update
    @update ||= HealthUpdate.new(project_id: project_id, date: date, health: health, description: description)
  end

  def save
    health_update_repository.save(update)
  end

  def success
    Result.success(value: update)
  end

  def failure(errors)
    Result.failure(errors: errors)
  end
end
