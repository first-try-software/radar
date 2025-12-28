require 'domain/initiatives/initiative'
require 'domain/initiatives/initiative_attributes'
require 'domain/initiatives/initiative_loaders'

module InitiativeBuilder
  def build_initiative(
    id: nil,
    name:,
    description: '',
    point_of_contact: '',
    archived: false,
    current_state: :new,
    related_projects_loader: nil
  )
    attributes = InitiativeAttributes.new(
      id: id,
      name: name,
      description: description,
      point_of_contact: point_of_contact,
      archived: archived,
      current_state: current_state
    )
    loaders = InitiativeLoaders.new(related_projects: related_projects_loader)
    Initiative.new(attributes: attributes, loaders: loaders)
  end
end
