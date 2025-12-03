require_relative '../support/result'
require_relative 'project'

class CreateProject
  def initialize(project_repository:)
    @project_repository = project_repository
  end

  def perform(name:, description: '', point_of_contact: '')
    project = Project.new(
      name: name,
      description: description,
      point_of_contact: point_of_contact
    )

    return failure_result(project) unless project.valid?

    project_repository.save(project)
    Result.success(value: project)
  end

  private

  attr_reader :project_repository

  def failure_result(project)
    Result.failure(errors: project.errors)
  end
end
