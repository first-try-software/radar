require 'domain/teams/team'
require 'domain/teams/team_attributes'
require 'domain/teams/team_loaders'

module TeamBuilder
  def build_team(
    id: nil,
    name:,
    description: '',
    point_of_contact: '',
    archived: false,
    owned_projects_loader: nil,
    subordinate_teams_loader: nil,
    parent_team_loader: nil
  )
    attributes = TeamAttributes.new(
      id: id,
      name: name,
      description: description,
      point_of_contact: point_of_contact,
      archived: archived
    )
    loaders = TeamLoaders.new(
      owned_projects: owned_projects_loader,
      subordinate_teams: subordinate_teams_loader,
      parent_team: parent_team_loader
    )
    Team.new(attributes: attributes, loaders: loaders)
  end
end
