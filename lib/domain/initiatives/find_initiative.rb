require_relative '../support/result'

class FindInitiative
  def initialize(initiative_repository:)
    @initiative_repository = initiative_repository
  end

  def perform(id:)
    initiative = initiative_repository.find(id)

    return initiative_not_found_failure unless initiative

    Result.success(value: initiative)
  end

  private

  attr_reader :initiative_repository

  def initiative_not_found_failure
    Result.failure(errors: 'initiative not found')
  end
end
