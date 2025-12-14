require_relative '../support/result'
require_relative 'project'
require_relative 'project_attributes'

class UnarchiveProject
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

  def unarchived_project
    @unarchived_project ||= Project.new(
      attributes: ProjectAttributes.new(
        name: project.name,
        description: project.description,
        point_of_contact: project.point_of_contact,
        archived: false
      )
    )
  end

  def project_not_found_failure
    failure('project not found')
  end

  def save
    project_repository.update(id: id, project: unarchived_project)
  end

  def success
    Result.success(value: unarchived_project)
  end

  def failure(errors)
    Result.failure(errors: errors)
  end
end
