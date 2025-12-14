require_relative '../support/result'

class UnlinkRelatedProject
  def initialize(initiative_repository:)
    @initiative_repository = initiative_repository
  end

  def perform(initiative_id:, project_id:)
    @initiative_id = initiative_id
    @project_id = project_id

    return initiative_not_found_failure unless initiative
    return relationship_not_found_failure unless relationship_exists?

    unlink_project
    success
  end

  private

  attr_reader :initiative_repository, :initiative_id, :project_id

  def initiative
    @initiative ||= initiative_repository.find(initiative_id)
  end

  def relationship_exists?
    initiative_repository.related_project_exists?(initiative_id: initiative_id, project_id: project_id)
  end

  def unlink_project
    initiative_repository.unlink_related_project(initiative_id: initiative_id, project_id: project_id)
  end

  def success
    Result.success(value: initiative)
  end

  def initiative_not_found_failure
    Result.failure(errors: 'initiative not found')
  end

  def relationship_not_found_failure
    Result.failure(errors: 'project not linked to initiative')
  end
end
