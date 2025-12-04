require_relative '../support/result'
require_relative 'initiative'

class ArchiveInitiative
  def initialize(initiative_repository:)
    @initiative_repository = initiative_repository
  end

  def perform(id:)
    @id = id

    return initiative_not_found_failure unless initiative

    save
    success
  end

  private

  attr_reader :initiative_repository, :id

  def initiative
    @initiative ||= initiative_repository.find(id)
  end

  def archived_initiative
    @archived_initiative ||= Initiative.new(
      name: initiative.name,
      description: initiative.description,
      point_of_contact: initiative.point_of_contact,
      archived: true
    )
  end

  def initiative_not_found_failure
    failure('initiative not found')
  end

  def save
    initiative_repository.save(id: id, initiative: archived_initiative)
  end

  def success
    Result.success(value: archived_initiative)
  end

  def failure(errors)
    Result.failure(errors: errors)
  end
end
