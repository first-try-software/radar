require_relative '../support/result'
require_relative 'project'

class UpdateProject
  def initialize(project_repository:)
    @project_repository = project_repository
  end

  def perform(id:, name:, description: '', point_of_contact: '')
    @id = id
    @attributes = { name:, description:, point_of_contact: }

    return project_not_found_failure unless existing_project
    return invalid_project_failure unless updated_project.valid?
    return duplicate_name_failure unless unique_name?

    save
    success
  end

  private

  attr_reader :project_repository, :id, :attributes

  def existing_project
    @existing_project ||= project_repository.find(id)
  end

  def updated_project
    @updated_project ||= Project.new(**attributes)
  end

  def duplicate_name?
    name_changed? && project_repository.exists_with_name?(updated_project.name)
  end

  def unique_name?
    !duplicate_name?
  end

  def name_changed?
    existing_project.name != updated_project.name
  end

  def project_not_found_failure
    failure(['project not found'])
  end

  def invalid_project_failure
    failure(updated_project.errors)
  end

  def duplicate_name_failure
    failure(['project name must be unique'])
  end

  def save
    project_repository.save(id: id, project: updated_project)
  end

  def success
    Result.success(value: updated_project)
  end

  def failure(errors)
    Result.failure(errors: errors)
  end
end
