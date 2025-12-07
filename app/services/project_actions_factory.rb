class ProjectActionsFactory
  def initialize(project_repository:)
    @project_repository = project_repository
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

  def find_project
    FindProject.new(project_repository: project_repository)
  end

  def create_subordinate_project
    CreateSubordinateProject.new(project_repository: project_repository)
  end

  private

  attr_reader :project_repository
end
