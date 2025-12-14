class InitiativeActionsFactory
  def initialize(initiative_repository:, project_repository:)
    @initiative_repository = initiative_repository
    @project_repository = project_repository
  end

  def create_initiative
    CreateInitiative.new(initiative_repository: initiative_repository)
  end

  def find_initiative
    @find_initiative ||= FindInitiative.new(initiative_repository: initiative_repository)
  end

  def update_initiative
    UpdateInitiative.new(initiative_repository: initiative_repository)
  end

  def archive_initiative
    ArchiveInitiative.new(initiative_repository: initiative_repository)
  end

  def link_related_project
    LinkRelatedProject.new(
      initiative_repository: initiative_repository,
      project_repository: project_repository
    )
  end

  def unlink_related_project
    UnlinkRelatedProject.new(initiative_repository: initiative_repository)
  end

  def set_initiative_state
    SetInitiativeState.new(
      initiative_repository: initiative_repository,
      project_repository: project_repository
    )
  end

  private

  attr_reader :initiative_repository, :project_repository
end
