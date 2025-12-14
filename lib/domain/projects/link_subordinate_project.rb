require_relative '../support/result'

class LinkSubordinateProject
  def initialize(project_repository:)
    @project_repository = project_repository
  end

  def perform(parent_id:, child_id:)
    @parent_id = parent_id
    @child_id = child_id

    return parent_not_found_failure unless parent
    return child_not_found_failure unless child
    return already_has_parent_failure if child_has_parent?

    link_project
    success
  end

  private

  attr_reader :project_repository, :parent_id, :child_id

  def parent
    @parent ||= project_repository.find(parent_id)
  end

  def child
    @child ||= project_repository.find(child_id)
  end

  def child_has_parent?
    project_repository.has_parent?(child_id: child_id)
  end

  def link_project
    order = project_repository.next_subordinate_order(parent_id: parent_id)
    project_repository.link_subordinate(parent_id: parent_id, child_id: child_id, order: order)
  end

  def success
    Result.success(value: child)
  end

  def parent_not_found_failure
    Result.failure(errors: 'parent project not found')
  end

  def child_not_found_failure
    Result.failure(errors: 'child project not found')
  end

  def already_has_parent_failure
    Result.failure(errors: 'project already has a parent')
  end
end
