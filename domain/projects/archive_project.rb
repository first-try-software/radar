require_relative '../support/result'
require_relative 'project'

class ArchiveProject
  def initialize(project_repository:)
    @project_repository = project_repository
  end

  def perform(id:)
    project = project_repository.find(id)
    return Result.failure(errors: ['project not found']) unless project

    archived_project = Project.new(
      name: project.name,
      description: project.description,
      point_of_contact: project.point_of_contact,
      archived: true
    )

    project_repository.save(id: id, project: archived_project)
    Result.success(value: archived_project)
  end

  private

  attr_reader :project_repository
end
