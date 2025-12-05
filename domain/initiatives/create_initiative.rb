require_relative '../support/result'
require_relative 'initiative'

class CreateInitiative
  def initialize(initiative_repository:)
    @initiative_repository = initiative_repository
  end

  def perform(name:, description: '', point_of_contact: '')
    @attributes = { name:, description:, point_of_contact: }

    return invalid_initiative_failure unless initiative.valid?
    return duplicate_name_failure if initiative_repository.exists_with_name?(initiative.name)

    save
    success
  end

  private

  attr_reader :initiative_repository, :attributes

  def initiative
    @initiative ||= Initiative.new(**attributes)
  end

  def invalid_initiative_failure
    failure(initiative.errors)
  end

  def duplicate_name_failure
    failure('initiative name must be unique')
  end

  def save
    initiative_repository.save(initiative)
  end

  def success
    Result.success(value: initiative)
  end

  def failure(errors)
    Result.failure(errors: errors)
  end
end
