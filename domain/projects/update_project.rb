require_relative '../support/result'
require_relative 'project'

class UpdateProject
  def initialize(project_repository:)
    @project_repository = project_repository
  end

  def perform(id:, name:, description: '', point_of_contact: '')
    existing_project = project_repository.find(id)
    return Result.failure(errors: ['project not found']) unless existing_project

    updated_project = Project.new(
      name: name,
      description: description,
      point_of_contact: point_of_contact
    )

    return Result.failure(errors: updated_project.errors) unless updated_project.valid?

    project_repository.save(id: id, project: updated_project)
    Result.success(value: updated_project)
  end

  private

  attr_reader :project_repository
end
