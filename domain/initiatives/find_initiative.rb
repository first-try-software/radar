require_relative '../support/result'

class FindInitiative
  def initialize(initiative_repository:)
    @initiative_repository = initiative_repository
  end

  def perform(id:)
    @id = id

    return initiative_not_found_failure unless initiative

    success
  end

  private

  attr_reader :initiative_repository, :id

  def initiative
    @initiative ||= initiative_repository.find(id)
  end

  def success
    Result.success(value: initiative)
  end

  def initiative_not_found_failure
    Result.failure(errors: ['initiative not found'])
  end
end
