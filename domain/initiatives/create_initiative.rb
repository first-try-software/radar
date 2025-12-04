require_relative '../support/result'
require_relative 'initiative'

class CreateInitiative
  def initialize(initiative_repository:)
    @initiative_repository = initiative_repository
  end

  def perform(name:, description: '')
    initiative = Initiative.new(name: name, description: description)

    return failure(initiative) unless initiative.valid?

    initiative_repository.save(initiative)
    Result.success(value: initiative)
  end

  private

  attr_reader :initiative_repository

  def failure(initiative)
    Result.failure(errors: initiative.errors)
  end
end
