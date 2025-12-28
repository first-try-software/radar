require_relative '../support/result'
require_relative 'project'
require_relative 'project_attributes'

class UpdateProject
  def initialize(project_repository:)
    @project_repository = project_repository
  end

  def perform(id:, name: nil, description: nil, point_of_contact: nil, archived: nil)
    @id = id
    @provided_attrs = { name:, description:, point_of_contact:, archived: }

    return project_not_found_failure unless existing_project
    return invalid_project_failure unless updated_project.valid?
    return duplicate_name_failure unless unique_name?

    save
    success
  end

  private

  attr_reader :project_repository, :id, :provided_attrs

  def existing_project
    @existing_project ||= project_repository.find(id)
  end

  def merged_attributes
    {
      name: provided_attrs[:name] || existing_project.name,
      description: provided_attrs[:description].nil? ? existing_project.description : provided_attrs[:description],
      point_of_contact: provided_attrs[:point_of_contact].nil? ? existing_project.point_of_contact : provided_attrs[:point_of_contact]
    }
  end

  def updated_attrs
    attrs = ProjectAttributes.new(**merged_attributes)
    archived_value = provided_attrs[:archived].nil? ? existing_project.archived? : provided_attrs[:archived]
    attrs.with(archived: archived_value, current_state: existing_project.current_state)
  end

  def updated_project
    @updated_project ||= Project.new(attributes: updated_attrs)
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
    failure('project not found')
  end

  def invalid_project_failure
    failure(updated_project.errors)
  end

  def duplicate_name_failure
    failure('project name must be unique')
  end

  def save
    project_repository.update(id: id, project: updated_project)
  end

  def success
    Result.success(value: updated_project)
  end

  def failure(errors)
    Result.failure(errors: errors)
  end
end
