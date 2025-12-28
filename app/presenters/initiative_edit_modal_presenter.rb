# frozen_string_literal: true

# Presenter for shared/_edit_modal.html.erb when editing an Initiative
class InitiativeEditModalPresenter
  def initialize(entity:, record:, view_context:)
    @entity = entity
    @record = record
    @view_context = view_context
  end

  # Display values
  def name
    @entity&.name || @record&.name || ''
  end

  def description
    @entity&.description || @record&.description || ''
  end

  def point_of_contact
    @entity&.point_of_contact || @record&.point_of_contact || ''
  end

  def archived?
    @record&.archived || false
  end

  # Form configuration
  def form_model = @record
  def update_path
    return nil unless @record

    @view_context.initiative_path(@record)
  end

  def form_method = :patch

  # Field naming
  def model_param_key = "initiative"
  def field_name(attribute) = "#{model_param_key}[#{attribute}]"
  def field_id(attribute) = "#{model_param_key}_#{attribute}"

  # Labels
  def entity_type_label = "Initiative"
  def modal_title = "Edit Initiative"
  def archive_prompt = "Archive this initiative and remove it from view?"

  def archive_label
    archived? ? "This initiative is archived and hidden." : "Click checkbox to archive"
  end
end
