require_relative '../support/result'

class FindProject
  def initialize(project_repository:)
    @project_repository = project_repository
  end

  def perform(id:)
    @id = id

    return project_not_found_failure unless project

    success
  end

  private

  attr_reader :project_repository, :id

  def project
    @project ||= project_repository.find(id)
  end

  def success
    Result.success(value: project)
  end

  def project_not_found_failure
    Result.failure(errors: ['project not found'])
  end
end
