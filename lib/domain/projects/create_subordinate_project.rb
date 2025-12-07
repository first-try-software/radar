require_relative '../support/result'
require_relative 'project'

class CreateSubordinateProject
  def initialize(project_repository:)
    @project_repository = project_repository
  end

  def perform(parent_id:, name:, description: '', point_of_contact: '')
    @parent_id = parent_id
    @attributes = { name:, description:, point_of_contact: }

    return parent_not_found_failure unless parent_project
    return invalid_project_failure unless subordinate_project.valid?
    return duplicate_name_failure unless unique_name?

    save_subordinate
    save_relationship
    success
  end

  private

  attr_reader :project_repository, :parent_id, :attributes

  def parent_project
    @parent_project ||= project_repository.find(parent_id)
  end

  def subordinate_project
    @subordinate_project ||= Project.new(**attributes)
  end

  def next_order
    project_repository.next_subordinate_order(parent_id: parent_id)
  end

  def unique_name?
    !project_repository.exists_with_name?(subordinate_project.name)
  end

  def save_subordinate
    project_repository.save(subordinate_project)
  end

  def save_relationship
    project_repository.link_subordinate(parent_id: parent_id, child: subordinate_project, order: next_order)
  end

  def success
    Result.success(value: subordinate_project)
  end

  def parent_not_found_failure
    failure('project not found')
  end

  def invalid_project_failure
    failure(subordinate_project.errors)
  end

  def duplicate_name_failure
    failure('project name must be unique')
  end

  def failure(errors)
    Result.failure(errors: errors)
  end
end
