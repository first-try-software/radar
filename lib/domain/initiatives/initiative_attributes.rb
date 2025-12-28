InitiativeAttributes = Data.define(
  :id,
  :name,
  :description,
  :point_of_contact,
  :archived,
  :current_state
) do
  ALLOWED_STATES = [:new, :todo, :in_progress, :blocked, :on_hold, :done].freeze

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

  def state_valid?
    ALLOWED_STATES.include?(current_state)
  end

  def valid?
    name_valid? && state_valid?
  end

  def errors
    errs = []
    errs << 'name must be present' unless name_valid?
    errs << 'state must be valid' unless state_valid?
    errs
  end
end
