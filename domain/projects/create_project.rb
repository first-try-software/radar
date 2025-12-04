require_relative '../support/result'
require_relative 'project'

class CreateProject
  def initialize(project_repository:)
    @project_repository = project_repository
  end

  def perform(name:, description: '', point_of_contact: '')
    @attributes = { name:, description:, point_of_contact: }

    return invalid_project_failure unless project.valid?
    return duplicate_name_failure unless unique_name?

    save
    success
  end

  private

  attr_reader :project_repository, :attributes

  def project
    @project ||= Project.new(**attributes)
  end

  def duplicate_name?
    project_repository.exists_with_name?(project.name)
  end

  def unique_name?
    !duplicate_name?
  end

  def invalid_project_failure
    failure(project.errors)
  end

  def duplicate_name_failure
    failure(['project name must be unique'])
  end

  def save
    project_repository.save(project)
  end

  def success
    Result.success(value: project)
  end

  def failure(errors)
    Result.failure(errors: errors)
  end
end
