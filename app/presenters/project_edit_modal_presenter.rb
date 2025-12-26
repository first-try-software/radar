# frozen_string_literal: true

# Presenter for shared/_edit_modal.html.erb when editing a Project
class ProjectEditModalPresenter
  def initialize(entity:, record:, view_context:)
    @entity = entity
    @record = record
    @view_context = view_context
  end

  # Display values
  def name = @entity.name
  def description = @entity.description
  def point_of_contact = @entity.point_of_contact
  def archived? = @record.archived

  # Form configuration
  def form_model = @record
  def update_path = @view_context.project_path(@record)
  def form_method = :patch

  # Field naming
  def model_param_key = "project"
  def field_name(attribute) = "#{model_param_key}[#{attribute}]"
  def field_id(attribute) = "#{model_param_key}_#{attribute}"

  # Labels
  def entity_type_label = "Project"
  def modal_title = "Edit Project"
  def archive_prompt = "Archive this project and remove it from view?"

  def archive_label
    archived? ? "This project is archived and hidden." : "Click checkbox to archive"
  end
end
