# frozen_string_literal: true

# Presenter for shared/_header.html.erb when displaying a Team
class TeamHeaderPresenter
  def initialize(entity:, record:, view_context:)
    @entity = entity
    @record = record
    @view_context = view_context
  end

  # Display attributes
  def name = @entity.name
  def description = @entity.description
  def description_present? = description.present?

  def point_of_contact
    @entity.effective_contact.presence || @entity.point_of_contact
  end

  def contact_present? = point_of_contact.present?
  def archived? = @record.archived

  # Teams don't have state
  def show_state_badge? = false
  def show_state_dropdown? = false
  def current_state = nil
  def state_css_class = nil
  def state_label = nil
  def allowed_states = []
  def state_path = nil

  # Navigation
  def breadcrumb
    @view_context.team_breadcrumb(@entity, @record)
  end

  # Edit form
  def edit_action = "edit-form#open"
  def entity_type_label = "Team"
end
