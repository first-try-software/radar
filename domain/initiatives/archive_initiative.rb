require_relative '../support/result'
require_relative 'initiative'

class ArchiveInitiative
  def initialize(initiative_repository:)
    @initiative_repository = initiative_repository
  end

  def perform(id:)
    initiative = initiative_repository.find(id)
    return Result.failure(errors: ['initiative not found']) unless initiative

    archived_initiative = Initiative.new(
      name: initiative.name,
      description: initiative.description,
      archived: true
    )

    initiative_repository.save(id: id, initiative: archived_initiative)
    Result.success(value: archived_initiative)
  end

  private

  attr_reader :initiative_repository
end
