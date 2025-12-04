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
    return duplicate_failure(existing_project, updated_project) if name_taken_by_other?(existing_project, updated_project)

    project_repository.save(id: id, project: updated_project)
    Result.success(value: updated_project)
  end

  private

  attr_reader :project_repository

  def name_taken_by_other?(existing_project, updated_project)
    existing_project.name != updated_project.name &&
      project_repository.exists_with_name?(updated_project.name)
  end

  def duplicate_failure(_existing_project, _updated_project)
    Result.failure(errors: ['project name must be unique'])
  end
end
