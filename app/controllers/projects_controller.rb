class ProjectsController < ApplicationController
  def show
    result = project_actions.find_project.perform(id: params[:id])

    respond_to do |format|
      format.json { render_result(result) }
      format.html do
        if result.success?
          @project = result.value
          @project_record = ProjectRecord.find(params[:id])
          prepare_health_form(project: @project)
          prepare_trend_data(project: @project)
          prepare_global_search_data
          if @project.leaf?
            prepare_health_updates
          end
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
      format.json do
        if result.success?
          record = ProjectRecord.find_by(name: result.value.name)
          render json: project_json(result.value).merge(url: project_path(record)), status: :created
        else
          render json: { errors: result.errors }, status: :unprocessable_content
        end
      end
      format.html do
        if result.success?
          record = ProjectRecord.find_by(name: result.value.name)
          redirect_to(project_path(record), notice: 'Project created')
        else
          redirect_to(root_path, alert: result.errors.join(', '))
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

  def unarchive
    result = project_actions.unarchive_project.perform(id: params[:id])

    respond_to do |format|
      format.json { render_result(result) }
      format.html do
        if result.success?
          redirect_to(project_path(params[:id]), notice: 'Project unarchived')
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

  def unlink_subordinate
    result = project_actions.unlink_subordinate_project.perform(
      parent_id: params[:id],
      child_id: params[:child_id]
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
          redirect_to(project_path(params[:id]), notice: 'Project unlinked')
        else
          render file: Rails.public_path.join('404.html'), status: :not_found, layout: false
        end
      end
    end
  end

  def link_subordinate
    result = project_actions.link_subordinate_project.perform(
      parent_id: params[:id],
      child_id: params[:child_id]
    )

    respond_to do |format|
      format.json { render_result(result, success_status: :created) }
      format.html do
        if result.success?
          redirect_to(project_path(params[:id]), notice: 'Project linked')
        else
          if result.errors.include?('parent project not found') || result.errors.include?('child project not found')
            render file: Rails.public_path.join('404.html'), status: :not_found, layout: false
          else
            # Parent exists if we get here (only 'project already has a parent' error reaches this branch)
            @project_record = ProjectRecord.find(params[:id])
            @project = project_actions.find_project.perform(id: params[:id]).value
            @errors = result.errors
            prepare_health_form(project: @project)
            render :show, status: :unprocessable_content
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
      format.turbo_stream do
        if result.success?
          @health_update = result.value
          @project_record = ProjectRecord.find(params[:id])
          @project = project_actions.find_project.perform(id: params[:id]).value
          prepare_trend_data(project: @project)
          render :create_health_update
        else
          render turbo_stream: turbo_stream.replace(
            "updates-section",
            partial: "projects/health_update_errors",
            locals: { errors: result.errors }
          )
        end
      end
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
    return :not_found if errors.include?('project not found')
    return :not_found if errors.include?('parent project not found')
    return :not_found if errors.include?('child project not found')
    return :not_found if errors.include?('project not linked to parent')

    :unprocessable_content
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
    permitted = params.fetch(:project, {}).permit(:name, :description, :point_of_contact).to_h.symbolize_keys
    permitted[:name] ||= ''
    permitted[:description] ||= ''
    permitted[:point_of_contact] ||= ''
    permitted
  end

  def update_params
    permitted = params.fetch(:project, {}).permit(:name, :description, :point_of_contact, :archived).to_h.symbolize_keys
    # Convert archived checkbox value to boolean if present
    if permitted.key?(:archived)
      permitted[:archived] = permitted[:archived] == '1' || permitted[:archived] == true || permitted[:archived] == 'true'
    end
    permitted
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

  def prepare_trend_data(project:)
    trend_service = ProjectTrendService.new(
      project: project,
      health_update_repository: health_update_repository
    )
    trend_result = trend_service.call

    @project_health = trend_result[:health]
    @health_summary = trend_result[:health_summary]
    @trend_data = trend_result[:trend_data]
    @trend_direction = trend_result[:trend_direction]
    @trend_delta = trend_result[:trend_delta]
    @weeks_of_data = trend_result[:weeks_of_data]
    @confidence_score = trend_result[:confidence_score]
    @confidence_level = trend_result[:confidence_level]
    @confidence_factors = trend_result[:confidence_factors]
  end

  def prepare_global_search_data
    @teams = team_repository.all_active_roots
    @initiatives = initiative_repository.all_active_roots
    @all_projects = project_repository.all_active_roots
  end

  def prepare_health_updates
    @health_updates = health_update_repository.all_for_project(params[:id]).sort_by(&:date).reverse
  end

  def team_repository
    Rails.application.config.x.team_repository
  end

  def initiative_repository
    Rails.application.config.x.initiative_repository
  end

  def project_repository
    Rails.application.config.x.project_repository
  end

  def health_update_repository
    Rails.application.config.x.health_update_repository
  end

  def health_options
    RecordProjectHealthUpdate::ALLOWED_HEALTHS
  end

  def selected_health_for(project)
    return health_options.first unless project

    health_options.include?(project.health) ? project.health : health_options.first
  end
end
