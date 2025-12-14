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

  def create_related_project
    CreateRelatedProject.new(
      initiative_repository: initiative_repository,
      project_repository: project_repository
    )
  end

  private

  attr_reader :initiative_repository, :project_repository
end
