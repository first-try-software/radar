class Project
  ALLOWED_STATES = [:new, :todo, :in_progress, :blocked, :on_hold, :done].freeze

  attr_reader :name, :description, :point_of_contact, :current_state

  def initialize(
    name:,
    description: '',
    point_of_contact: '',
    archived: false,
    subordinates_loader: nil,
    current_state: :new,
    state_description: nil
  )
    @name = name.to_s
    @description = description.to_s
    @point_of_contact = point_of_contact.to_s
    @archived = archived
    @subordinates_loader = subordinates_loader
    @subordinate_projects = nil
    @current_state = normalize_state(current_state)
  end

  def valid?
    !name.strip.empty?
  end

  def errors
    return [] if valid?

    ['name must be present']
  end

  def archived?
    !!@archived
  end

  def subordinate_projects
    @subordinate_projects ||= load_subordinates
  end

  def with_state(state:)
    self.class.new(
      name: name,
      description: self.description,
      point_of_contact: point_of_contact,
      archived: archived?,
      subordinates_loader: @subordinates_loader,
      current_state: state
    )
  end

  private

  attr_reader :subordinates_loader

  def load_subordinates
    return [] unless subordinates_loader

    subordinates_loader.call(self)
  end

  def normalize_state(state)
    symbol = state&.to_sym
    raise ArgumentError, 'invalid project state' unless ALLOWED_STATES.include?(symbol)

    symbol
  end
end
