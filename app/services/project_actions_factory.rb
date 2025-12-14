class ProjectActionsFactory
  def initialize(project_repository:, health_update_repository:)
    @project_repository = project_repository
    @health_update_repository = health_update_repository
  end

  def create_project
    CreateProject.new(project_repository: project_repository)
  end

  def update_project
    UpdateProject.new(project_repository: project_repository)
  end

  def set_project_state
    SetProjectState.new(project_repository: project_repository)
  end

  def archive_project
    ArchiveProject.new(project_repository: project_repository)
  end

  def unarchive_project
    UnarchiveProject.new(project_repository: project_repository)
  end

  def find_project
    @find_project ||= FindProject.new(project_repository: project_repository)
  end

  def create_subordinate_project
    CreateSubordinateProject.new(project_repository: project_repository)
  end

  def unlink_subordinate_project
    UnlinkSubordinateProject.new(project_repository: project_repository)
  end

  def link_subordinate_project
    LinkSubordinateProject.new(project_repository: project_repository)
  end

  def record_project_health_update
    RecordProjectHealthUpdate.new(
      project_repository: project_repository,
      health_update_repository: health_update_repository
    )
  end

  private

  attr_reader :project_repository, :health_update_repository
end
