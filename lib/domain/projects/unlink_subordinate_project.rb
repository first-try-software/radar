require_relative '../support/result'

class UnlinkSubordinateProject
  def initialize(project_repository:)
    @project_repository = project_repository
  end

  def perform(parent_id:, child_id:)
    @parent_id = parent_id
    @child_id = child_id

    return parent_not_found_failure unless parent
    return relationship_not_found_failure unless relationship_exists?

    unlink_project
    success
  end

  private

  attr_reader :project_repository, :parent_id, :child_id

  def parent
    @parent ||= project_repository.find(parent_id)
  end

  def relationship_exists?
    project_repository.subordinate_exists?(parent_id: parent_id, child_id: child_id)
  end

  def unlink_project
    project_repository.unlink_subordinate(parent_id: parent_id, child_id: child_id)
  end

  def success
    Result.success(value: parent)
  end

  def parent_not_found_failure
    Result.failure(errors: 'parent project not found')
  end

  def relationship_not_found_failure
    Result.failure(errors: 'project not linked to parent')
  end
end
