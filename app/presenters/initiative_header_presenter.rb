# frozen_string_literal: true

# Presenter for shared/_header.html.erb when displaying an Initiative
class InitiativeHeaderPresenter
  ALLOWED_STATES = %i[new in_progress on_hold done].freeze

  def initialize(entity:, record:, view_context:)
    @entity = entity
    @record = record
    @view_context = view_context
  end

  # Display attributes
  def name = @entity.name
  def description = @entity.description
  def description_present? = description.present?
  def point_of_contact = @entity.point_of_contact
  def contact_present? = point_of_contact.present?
  def archived? = @record.archived

  # Initiatives have state
  def current_state = @entity.current_state
  def show_state_badge? = current_state.present?
  def show_state_dropdown? = show_state_badge?
  def state_css_class = current_state.to_s.tr("_", "-")
  def state_label = current_state.to_s.tr("_", " ").titleize
  def allowed_states = ALLOWED_STATES

  def state_path
    @view_context.state_initiative_path(@record)
  end

  # Navigation
  def breadcrumb
    @view_context.initiative_breadcrumb(@entity, @record)
  end

  # Edit form
  def edit_action = "edit-form#open"
  def entity_type_label = "Initiative"
end
