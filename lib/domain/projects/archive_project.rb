require_relative '../support/result'
require_relative 'project'
require_relative 'project_attributes'

class ArchiveProject
  def initialize(project_repository:)
    @project_repository = project_repository
  end

  def perform(id:)
    @id = id

    return project_not_found_failure unless project

    save
    success
  end

  private

  attr_reader :project_repository, :id

  def project
    @project ||= project_repository.find(id)
  end

  def archived_project
    @archived_project ||= Project.new(
      attributes: ProjectAttributes.new(
        name: project.name,
        description: project.description,
        point_of_contact: project.point_of_contact,
        archived: true
      )
    )
  end

  def project_not_found_failure
    failure('project not found')
  end

  def save
    project_repository.update(id: id, project: archived_project)
  end

  def success
    Result.success(value: archived_project)
  end

  def failure(errors)
    Result.failure(errors: errors)
  end
end
