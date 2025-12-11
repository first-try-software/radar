require_relative '../support/result'

class FindProject
  def initialize(project_repository:)
    @project_repository = project_repository
  end

  def perform(id:)
    project = project_repository.find(id)
    return project_not_found_failure unless project

    success(project)
  end

  private

  attr_reader :project_repository

  def success(project)
    Result.success(value: project)
  end

  def project_not_found_failure
    Result.failure(errors: 'project not found')
  end
end
