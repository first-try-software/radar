require_relative '../support/result'

class FindInitiative
  def initialize(initiative_repository:)
    @initiative_repository = initiative_repository
  end

  def perform(id:)
    initiative = initiative_repository.find(id)
    return Result.failure(errors: ['initiative not found']) unless initiative

    Result.success(value: initiative)
  end

  private

  attr_reader :initiative_repository
end
