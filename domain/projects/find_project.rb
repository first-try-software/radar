require_relative '../support/result'

class FindProject
  def initialize(project_repository:)
    @project_repository = project_repository
  end

  def perform(id:)
    project = project_repository.find(id)
    return Result.failure(errors: ['project not found']) unless project

    Result.success(value: project)
  end

  private

  attr_reader :project_repository
end
