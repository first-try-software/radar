class InitiativesController < ApplicationController
  def index
    @initiatives = InitiativeRecord.order(:name)

    respond_to do |format|
      format.html
      format.json { render json: @initiatives.map { |init| initiative_json(init) }, status: :ok }
    end
  end

  def show
    result = initiative_actions.find_initiative.perform(id: params[:id])

    respond_to do |format|
      format.json { render_result(result) }
      format.html do
        if result.success?
          @initiative = result.value
          @initiative_record = InitiativeRecord.find(params[:id])
          render :show
        else
          render file: Rails.public_path.join('404.html'), status: :not_found, layout: false
        end
      end
    end
  end

  def create
    result = initiative_actions.create_initiative.perform(**create_params)

    respond_to do |format|
      format.json { render_result(result, success_status: :created) }
      format.html do
        if result.success?
          record = InitiativeRecord.find_by(name: result.value.name)
          redirect_to(initiative_path(record), notice: 'Initiative created')
        else
          @initiatives = InitiativeRecord.order(:name)
          @errors = result.errors
          render :index, status: :unprocessable_content
        end
      end
    end
  end

  def update
    record = InitiativeRecord.find(params[:id])
    attrs = {
      name: record.name,
      description: record.description,
      point_of_contact: record.point_of_contact
    }.merge(update_params.compact)

    result = initiative_actions.update_initiative.perform(id: params[:id], **attrs)

    respond_to do |format|
      format.json { render_result(result) }
      format.html do
        if result.success?
          redirect_to(initiative_path(params[:id]), notice: 'Initiative updated')
        else
          @initiative_record = InitiativeRecord.find(params[:id])
          @initiative = result.value
          @errors = result.errors
          render :show, status: error_status(result.errors)
        end
      end
    end
  end

  def archive
    result = initiative_actions.archive_initiative.perform(id: params[:id])

    respond_to do |format|
      format.json { render_result(result) }
      format.html do
        if result.success?
          redirect_to(initiative_path(params[:id]), notice: 'Initiative archived')
        else
          render file: Rails.public_path.join('404.html'), status: :not_found, layout: false
        end
      end
    end
  end

  def link_related_project
    result = initiative_actions.link_related_project.perform(
      initiative_id: params[:id],
      project_id: params[:project_id]
    )

    respond_to do |format|
      format.json { render_project_result(result, success_status: :created) }
      format.html do
        if result.success?
          redirect_to(initiative_path(params[:id]), notice: 'Project linked')
        else
          render file: Rails.public_path.join('404.html'), status: :not_found, layout: false
        end
      end
    end
  end

  def unlink_related_project
    result = initiative_actions.unlink_related_project.perform(
      initiative_id: params[:id],
      project_id: params[:project_id]
    )

    respond_to do |format|
      format.json do
        if result.success?
          render json: { success: true }, status: :ok
        else
          render json: { errors: result.errors }, status: error_status(result.errors)
        end
      end
      format.html do
        if result.success?
          redirect_to(initiative_path(params[:id]), notice: 'Project unlinked')
        else
          render file: Rails.public_path.join('404.html'), status: :not_found, layout: false
        end
      end
    end
  end

  private

  def initiative_actions
    Rails.application.config.x.initiative_actions
  end

  def render_result(result, success_status: :ok)
    if result.success?
      render json: initiative_json(result.value), status: success_status
    else
      render json: { errors: result.errors }, status: error_status(result.errors)
    end
  end

  def render_project_result(result, success_status: :ok)
    if result.success?
      render json: project_json(result.value), status: success_status
    else
      render json: { errors: result.errors }, status: error_status(result.errors)
    end
  end

  def error_status(errors)
    return :not_found if errors.include?('initiative not found')
    return :not_found if errors.include?('project not found')
    return :not_found if errors.include?('project not linked to initiative')

    :unprocessable_content
  end

  def initiative_json(initiative)
    {
      name: initiative.name,
      description: initiative.description,
      point_of_contact: initiative.point_of_contact,
      archived: initiative.archived?
    }
  end

  def project_json(project)
    {
      name: project.name,
      description: project.description,
      point_of_contact: project.point_of_contact,
      current_state: project.current_state,
      archived: project.archived?
    }
  end

  def create_params
    permitted = params.fetch(:initiative, {}).permit(:name, :description, :point_of_contact).to_h.symbolize_keys
    permitted[:name] ||= ''
    permitted[:description] ||= ''
    permitted[:point_of_contact] ||= ''
    permitted
  end

  def update_params
    params.fetch(:initiative, {}).permit(:name, :description, :point_of_contact).to_h.symbolize_keys
  end
end
