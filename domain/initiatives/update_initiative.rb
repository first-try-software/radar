require_relative '../support/result'
require_relative 'initiative'

class UpdateInitiative
  def initialize(initiative_repository:)
    @initiative_repository = initiative_repository
  end

  def perform(id:, name:, description: '', archived: false)
    existing_initiative = initiative_repository.find(id)
    return Result.failure(errors: ['initiative not found']) unless existing_initiative

    updated_initiative = Initiative.new(
      name: name,
      description: description,
      archived: archived
    )

    return Result.failure(errors: updated_initiative.errors) unless updated_initiative.valid?

    initiative_repository.save(id: id, initiative: updated_initiative)
    Result.success(value: updated_initiative)
  end

  private

  attr_reader :initiative_repository
end
