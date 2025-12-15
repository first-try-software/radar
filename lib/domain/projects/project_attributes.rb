ProjectAttributes = Data.define(
  :id,
  :name,
  :description,
  :point_of_contact,
  :archived,
  :current_state
) do
  def initialize(
    name:,
    id: nil,
    description: '',
    point_of_contact: '',
    archived: false,
    current_state: :new
  )
    super(
      id: id&.to_s,
      name: name.to_s,
      description: description.to_s,
      point_of_contact: point_of_contact.to_s,
      archived: archived,
      current_state: (current_state || :new).to_sym
    )
  end

  def with_state(state)
    with(current_state: state)
  end

  def archived?
    !!archived
  end

  def name_valid?
    !name.strip.empty?
  end

  def name_errors
    return [] if name_valid?

    ['name must be present']
  end
end
