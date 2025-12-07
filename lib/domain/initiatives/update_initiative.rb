require_relative '../support/result'
require_relative 'initiative'

class UpdateInitiative
  def initialize(initiative_repository:)
    @initiative_repository = initiative_repository
  end

  def perform(id:, name:, description: '', point_of_contact: '', archived: false)
    @id = id
    @attributes = { name:, description:, point_of_contact:, archived: }

    return initiative_not_found_failure unless existing_initiative
    return invalid_initiative_failure unless updated_initiative.valid?
    return duplicate_name_failure if name_conflict?

    save
    success
  end

  private

  attr_reader :initiative_repository, :id, :attributes

  def existing_initiative
    @existing_initiative ||= initiative_repository.find(id)
  end

  def updated_initiative
    @updated_initiative ||= Initiative.new(**attributes)
  end

  def initiative_not_found_failure
    failure('initiative not found')
  end

  def invalid_initiative_failure
    failure(updated_initiative.errors)
  end

  def name_conflict?
    initiative_repository.exists_with_name?(updated_initiative.name) &&
      updated_initiative.name != existing_initiative.name
  end

  def duplicate_name_failure
    failure('initiative name must be unique')
  end

  def save
    initiative_repository.update(id: id, initiative: updated_initiative)
  end

  def success
    Result.success(value: updated_initiative)
  end

  def failure(errors)
    Result.failure(errors: errors)
  end
end
