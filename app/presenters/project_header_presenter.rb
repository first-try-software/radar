# frozen_string_literal: true

# Presenter for shared/_header.html.erb when displaying a Project
class ProjectHeaderPresenter
  ALLOWED_STATES = %i[new todo in_progress blocked on_hold done].freeze

  def initialize(entity:, view_context:)
    @entity = entity
    @view_context = view_context
  end

  # Display attributes
  def name = @entity.name
  def description = @entity.description
  def description_present? = description.present?
  def point_of_contact = @entity.point_of_contact
  def contact_present? = point_of_contact.present?
  def archived? = @entity.archived?

  # Projects have state
  def current_state = @entity.current_state
  def show_state_badge? = current_state.present?
  def show_state_dropdown? = show_state_badge?
  def state_css_class = current_state.to_s.tr("_", "-")
  def state_label = current_state.to_s.tr("_", " ").titleize
  def allowed_states = ALLOWED_STATES

  def state_path
    @view_context.state_project_path(@entity.id)
  end

  # Navigation
  def breadcrumb
    @view_context.project_breadcrumb(@entity)
  end

  # Edit form
  def edit_action = "edit-form#open"
  def entity_type_label = "Project"
end
