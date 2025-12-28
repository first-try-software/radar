require_relative '../support/result'

class LinkRelatedProject
  def initialize(initiative_repository:, project_repository:)
    @initiative_repository = initiative_repository
    @project_repository = project_repository
  end

  def perform(initiative_id:, project_id:)
    @initiative_id = initiative_id
    @project_id = project_id

    return initiative_not_found_failure unless initiative
    return project_not_found_failure unless project
    return project_has_parent_failure if project_has_parent?

    link_project
    success
  end

  private

  attr_reader :initiative_repository, :project_repository, :initiative_id, :project_id

  def initiative
    @initiative ||= initiative_repository.find(initiative_id)
  end

  def project
    @project ||= project_repository.find(project_id)
  end

  def link_project
    order = initiative_repository.next_related_project_order(initiative_id: initiative_id)
    initiative_repository.link_related_project(initiative_id: initiative_id, project: project, order: order)
  end

  def success
    Result.success(value: project)
  end

  def initiative_not_found_failure
    Result.failure(errors: 'initiative not found')
  end

  def project_not_found_failure
    Result.failure(errors: 'project not found')
  end

  def project_has_parent?
    project.parent != nil
  end

  def project_has_parent_failure
    Result.failure(errors: 'only top-level projects can be related to initiatives')
  end
end
