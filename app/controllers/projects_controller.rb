class ProjectsController < ApplicationController
  def index
    @projects = root_projects.order(:name)

    respond_to do |format|
      format.html
      format.json { render json: @projects.map { |proj| project_json(proj) }, status: :ok }
    end
  end

  def show
    result = project_actions.find_project.perform(id: params[:id])

    respond_to do |format|
      format.json { render_result(result) }
      format.html do
        if result.success?
          @project = result.value
          @project_record = ProjectRecord.find(params[:id])
          prepare_health_form(project: @project)
          render :show
        else
          render file: Rails.public_path.join('404.html'), status: :not_found, layout: false
        end
      end
    end
  end

  def create
    result = project_actions.create_project.perform(**create_params)

    respond_to do |format|
      format.json { render_result(result, success_status: :created) }
      format.html do
        if result.success?
          record = ProjectRecord.find_by(name: result.value.name)
          redirect_to(project_path(record), notice: 'Project created')
        else
          @projects = root_projects.order(:name)
          @errors = result.errors
          render :index, status: :unprocessable_content
        end
      end
    end
  end

  def update
    record = ProjectRecord.find(params[:id])
    attrs = {
      name: record.name,
      description: record.description,
      point_of_contact: record.point_of_contact
    }.merge(update_params.compact)

    result = project_actions.update_project.perform(id: params[:id], **attrs)

    respond_to do |format|
      format.json { render_result(result) }
      format.html do
        if result.success?
          redirect_to(project_path(params[:id]), notice: 'Project updated')
        else
          @project_record = ProjectRecord.find(params[:id])
          @project = result.value
          @errors = result.errors
          prepare_health_form(project: @project)
          render :show, status: error_status(result.errors)
        end
      end
    end
  end

  def set_state
    result = project_actions.set_project_state.perform(id: params[:id], state: params[:state])

    respond_to do |format|
      format.json { render_result(result) }
      format.html do
        if result.success?
          redirect_to(project_path(params[:id]), notice: 'State updated')
        else
          @project_record = ProjectRecord.find_by(id: params[:id])
          return render file: Rails.public_path.join('404.html'), status: :not_found, layout: false unless @project_record

          @project = project_actions.find_project.perform(id: params[:id]).value
          @errors = result.errors
          prepare_health_form(project: @project)
          render :show, status: error_status(result.errors)
        end
      end
    end
  end

  def archive
    result = project_actions.archive_project.perform(id: params[:id])

    respond_to do |format|
      format.json { render_result(result) }
      format.html do
        if result.success?
          redirect_to(project_path(params[:id]), notice: 'Project archived')
        else
          render file: Rails.public_path.join('404.html'), status: :not_found, layout: false
        end
      end
    end
  end

  def create_subordinate
    result = project_actions.create_subordinate_project.perform(parent_id: params[:id], **create_params)

    respond_to do |format|
      format.json { render_result(result, success_status: :created) }
      format.html do
        if result.success?
          redirect_to(project_path(params[:id]), notice: 'Child project created')
        else
          if result.errors.include?('project not found')
            render file: Rails.public_path.join('404.html'), status: :not_found, layout: false
          else
            @project_record = ProjectRecord.find_by(id: params[:id])
            return render file: Rails.public_path.join('404.html'), status: :not_found, layout: false unless @project_record

            @project = project_actions.find_project.perform(id: params[:id]).value
            @errors = result.errors
            prepare_health_form(project: @project)
            render :show, status: error_status(result.errors)
          end
        end
      end
    end
  end

  def create_health_update
    attrs = health_update_attributes
    result = project_actions.record_project_health_update.perform(
      project_id: params[:id],
      date: attrs[:date],
      health: attrs[:health],
      description: attrs[:description]
    )

    respond_to do |format|
      format.json { render_health_update_result(result) }
      format.html do
        if result.success?
          redirect_to(project_path(params[:id]), notice: 'Health updated')
        else
          render_health_update_errors(result)
        end
      end
    end
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

  def root_projects
    ProjectRecord.left_outer_joins(:parent_relationship).where(projects_projects: { parent_id: nil })
  end

  def create_params
    permitted = params.fetch(:project, {}).permit(:name, :description, :point_of_contact).to_h.symbolize_keys
    permitted[:name] ||= ''
    permitted[:description] ||= ''
    permitted[:point_of_contact] ||= ''
    permitted
  end

  def update_params
    params.fetch(:project, {}).permit(:name, :description, :point_of_contact).to_h.symbolize_keys
  end

  def health_update_params
    params.fetch(:health_update, {}).permit(:date, :health, :description)
  end

  def health_update_attributes
    permitted = health_update_params.to_h.symbolize_keys
    {
      date: parse_date(permitted[:date]),
      health: permitted[:health],
      description: permitted[:description]
    }
  end

  def parse_date(value)
    return value if value.is_a?(Date)
    return nil if value.nil? || value == ''

    Date.parse(value)
  rescue ArgumentError
    nil
  end

  def render_health_update_result(result)
    if result.success?
      project_id = result.value.project_id
      project = project_actions.find_project.perform(id: project_id).value
      render json: { health: project.health }, status: :created
    else
      render json: { errors: result.errors }, status: error_status(result.errors)
    end
  end

  def render_health_update_errors(result)
    if result.errors.include?('project not found')
      render file: Rails.public_path.join('404.html'), status: :not_found, layout: false
      return
    end

    @project_record = ProjectRecord.find_by(id: params[:id])
    return render file: Rails.public_path.join('404.html'), status: :not_found, layout: false unless @project_record

    @project = project_actions.find_project.perform(id: params[:id]).value
    @errors = result.errors
    prepare_health_form(project: @project, open: true)
    render :show, status: error_status(result.errors)
  end

  def prepare_health_form(project:, open: false)
    @health_options = health_options
    @selected_health = selected_health_for(project)
    @show_health_update_form = open
  end

  def health_options
    RecordProjectHealthUpdate::ALLOWED_HEALTHS
  end

  def selected_health_for(project)
    return health_options.first unless project

    health_options.include?(project.health) ? project.health : health_options.first
  end
end
