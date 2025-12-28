TeamAttributes = Data.define(
  :id,
  :name,
  :description,
  :point_of_contact,
  :archived
) do
  def initialize(
    name:,
    id: nil,
    description: '',
    point_of_contact: '',
    archived: false
  )
    super(
      id: id&.to_s,
      name: name.to_s,
      description: description.to_s,
      point_of_contact: point_of_contact.to_s,
      archived: archived
    )
  end

  def archived?
    !!archived
  end

  def name_valid?
    !name.strip.empty?
  end

  def valid?
    name_valid?
  end

  def errors
    return [] if valid?

    ['name must be present']
  end
end
