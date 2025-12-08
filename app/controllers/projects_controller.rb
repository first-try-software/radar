class ProjectsController < ApplicationController
  def show
    render_result project_actions.find_project.perform(id: params[:id])
  end

  def create
    render_result project_actions.create_project.perform(**create_params), success_status: :created
  end

  def update
    render_result project_actions.update_project.perform(id: params[:id], **update_params)
  end

  def set_state
    render_result project_actions.set_project_state.perform(id: params[:id], state: params[:state])
  end

  def archive
    render_result project_actions.archive_project.perform(id: params[:id])
  end

  def create_subordinate
    render_result project_actions.create_subordinate_project.perform(parent_id: params[:id], **create_params), success_status: :created
  end

  private

  def project_actions
    Rails.application.config.x.project_actions
  end

  def render_result(result, success_status: :ok)
    if result.success?
      render json: project_json(result.value), status: success_status
    else
      render json: { errors: result.errors }, status: error_status(result.errors)
    end
  end

  def error_status(errors)
    errors.include?('project not found') ? :not_found : :unprocessable_content
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
    params.require(:project).permit(:name, :description, :point_of_contact).to_h.symbolize_keys
  end

  def update_params
    params.require(:project).permit(:name, :description, :point_of_contact).to_h.symbolize_keys
  end
end
