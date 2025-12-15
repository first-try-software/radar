class TeamActionsFactory
  def initialize(team_repository:, project_repository:)
    @team_repository = team_repository
    @project_repository = project_repository
  end

  def create_team
    CreateTeam.new(team_repository: team_repository)
  end

  def find_team
    @find_team ||= FindTeam.new(team_repository: team_repository)
  end

  def update_team
    UpdateTeam.new(team_repository: team_repository)
  end

  def archive_team
    ArchiveTeam.new(team_repository: team_repository)
  end

  def create_subordinate_team
    CreateSubordinateTeam.new(team_repository: team_repository)
  end

  def link_owned_project
    LinkOwnedProject.new(
      team_repository: team_repository,
      project_repository: project_repository
    )
  end

  private

  attr_reader :team_repository, :project_repository
end
