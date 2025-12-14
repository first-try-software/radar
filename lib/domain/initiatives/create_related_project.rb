require_relative '../support/result'
require_relative '../projects/project'
require_relative '../projects/project_attributes'

class CreateRelatedProject
  def initialize(initiative_repository:, project_repository:)
    @initiative_repository = initiative_repository
    @project_repository = project_repository
  end

  def perform(initiative_id:, name:, description: '', point_of_contact: '')
    @initiative_id = initiative_id
    @attrs = ProjectAttributes.new(name:, description:, point_of_contact:)

    return initiative_not_found_failure unless initiative
    return invalid_project_failure unless project.valid?
    return duplicate_name_failure unless unique_name?

    save_project
    link_project
    success
  end

  private

  attr_reader :initiative_repository, :project_repository, :initiative_id, :attrs

  def initiative
    @initiative ||= initiative_repository.find(initiative_id)
  end

  def project
    @project ||= Project.new(attributes: attrs)
  end

  def unique_name?
    !project_repository.exists_with_name?(project.name)
  end

  def save_project
    project_repository.save(project)
  end

  def link_project
    order = initiative_repository.next_related_project_order(initiative_id: initiative_id)
    initiative_repository.link_related_project(initiative_id: initiative_id, project: project, order: order)
  end

  def success
    Result.success(value: project)
  end

  def initiative_not_found_failure
    failure('initiative not found')
  end

  def invalid_project_failure
    failure(project.errors)
  end

  def duplicate_name_failure
    failure('project name must be unique')
  end

  def failure(errors)
    Result.failure(errors: errors)
  end
end
