TeamLoaders = Data.define(
  :owned_projects,
  :subordinate_teams,
  :parent_team
) do
  def initialize(owned_projects: nil, subordinate_teams: nil, parent_team: nil)
    super
  end
end
