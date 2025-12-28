require_relative '../support/result'
require_relative 'initiative'
require_relative 'initiative_attributes'

class UpdateInitiative
  def initialize(initiative_repository:)
    @initiative_repository = initiative_repository
  end

  def perform(id:, name: nil, description: nil, point_of_contact: nil, archived: nil)
    @id = id
    @provided_attrs = { name:, description:, point_of_contact:, archived: }

    return initiative_not_found_failure unless existing_initiative
    return invalid_initiative_failure unless updated_initiative.valid?
    return duplicate_name_failure if name_conflict?

    save
    success
  end

  private

  attr_reader :initiative_repository, :id, :provided_attrs

  def existing_initiative
    @existing_initiative ||= initiative_repository.find(id)
  end

  def merged_attributes
    InitiativeAttributes.new(
      id: existing_initiative.id,
      name: provided_attrs[:name] || existing_initiative.name,
      description: provided_attrs[:description].nil? ? existing_initiative.description : provided_attrs[:description],
      point_of_contact: provided_attrs[:point_of_contact].nil? ? existing_initiative.point_of_contact : provided_attrs[:point_of_contact],
      archived: provided_attrs[:archived].nil? ? existing_initiative.archived? : provided_attrs[:archived]
    )
  end

  def updated_initiative
    @updated_initiative ||= Initiative.new(attributes: merged_attributes)
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
