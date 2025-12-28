# frozen_string_literal: true

# Presenter for shared/_edit_modal.html.erb when editing a Team
class TeamEditModalPresenter
  def initialize(entity:, view_context:)
    @entity = entity
    @view_context = view_context
  end

  # Display values
  def name
    @entity&.name || ''
  end

  def description
    @entity&.description || ''
  end

  def point_of_contact
    @entity&.point_of_contact || ''
  end

  def archived?
    @entity&.archived? || false
  end

  # Form configuration
  def update_path
    return nil unless @entity

    @view_context.team_path(@entity.id)
  end

  def form_method = :patch

  # Field naming
  def model_param_key = "team"
  def field_name(attribute) = "#{model_param_key}[#{attribute}]"
  def field_id(attribute) = "#{model_param_key}_#{attribute}"

  # Labels
  def entity_type_label = "Team"
  def modal_title = "Edit Team"
  def archive_prompt = "Archive this team and remove it from view?"

  def archive_label
    archived? ? "This team is archived and hidden." : "Click checkbox to archive"
  end
end
