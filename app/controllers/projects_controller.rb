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
          @project = result.value || project_actions.find_project.perform(id: params[:id]).value
          @errors = result.errors
          prepare_show_for_errors
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
          prepare_show_for_errors
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
      format.turbo_stream do
        if result.success?
          @project_record = ProjectRecord.find_by(id: params[:id])
          @project = project_actions.find_project.perform(id: params[:id]).value
          @child_project = result.value
          render :create_subordinate
        else
          @errors = result.errors
          render turbo_stream: turbo_stream.append("toast-container",
            "<div class='toast toast--error toast--visible'>#{result.errors.join(', ')}</div>".html_safe
          ), status: :unprocessable_content
        end
      end
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
            prepare_show_for_errors
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
            prepare_show_for_errors
            render :show, status: :unprocessable_content
          end
        end
      end
    end
  end

  def create_health_update
    attrs = health_update_attributes
    result = project_actions.create_project_health_update.perform(
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
          prepare_global_search_data
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
    prepare_show_for_errors
    render :show, status: error_status(result.errors)
  end

  def prepare_show_for_errors
    prepare_health_form(project: @project, open: true)
    prepare_trend_data(project: @project)
    prepare_global_search_data
  end

  def prepare_health_form(project:, open: false)
    @health_options = health_options
    @selected_health = selected_health_for(project)
    @show_health_update_form = open
  end

  def prepare_trend_data(project:)
    trend_service = ProjectTrendService.new(
      project: project,
      health_update_repository: health_update_repository,
      current_date: Date.current
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

    # Build presenters for shared partials
    build_project_presenters(@project)
  end

  def build_project_presenters(project)
    # Header presenter
    @header_presenter = ProjectHeaderPresenter.new(
      entity: project,
      record: @project_record,
      view_context: view_context
    )

    # Metric presenters
    is_leaf = project.leaf?

    if is_leaf
      methodology = "Based on the most recent health update for this project."
      off_track_count = 0
      at_risk_count = 0
      total_count = 0
    else
      methodology = "Average of all leaf-node project health scores."
      children = project.children || []
      active_states = [:in_progress, :blocked]
      active_children = children.select { |p| active_states.include?(p.current_state) }
      off_track_count = active_children.count { |p| p.health == :off_track }
      at_risk_count = active_children.count { |p| p.health == :at_risk }
      total_count = active_children.size
    end

    @health_presenter = HealthPresenter.new(
      health: @project_health || project.health,
      raw_score: @health_summary&.dig(:raw_score),
      off_track_count: off_track_count,
      at_risk_count: at_risk_count,
      total_count: total_count,
      methodology: methodology
    )

    @trend_presenter = TrendPresenter.new(
      trend_data: @trend_data,
      trend_direction: @trend_direction,
      trend_delta: @trend_delta,
      weeks_of_data: @weeks_of_data,
      gradient_id: "project-trend-gradient"
    )

    @confidence_presenter = ConfidencePresenter.new(
      score: @confidence_score,
      level: @confidence_level,
      factors: @confidence_factors || {}
    )

    # Edit modal presenter
    @edit_modal_presenter = ProjectEditModalPresenter.new(
      entity: project,
      record: @project_record,
      view_context: view_context
    )

    # Search data
    build_search_data
  end

  def build_search_data
    @search_teams = []
    build_team_tree = ->(teams) do
      teams.sort_by(&:name).each do |t|
        @search_teams << { entity: t, record: TeamRecord.find_by(name: t.name) }
        build_team_tree.call(t.subordinate_teams) if t.subordinate_teams.any?
      end
    end
    build_team_tree.call(@teams)

    @search_initiatives = @initiatives.map do |i|
      { entity: i, record: InitiativeRecord.find_by(name: i.name) }
    end

    @search_projects = @all_projects.map do |p|
      { entity: p, record: ProjectRecord.find_by(name: p.name) }
    end
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
    CreateProjectHealthUpdate::ALLOWED_HEALTHS
  end

  def selected_health_for(project)
    return health_options.first unless project

    health_options.include?(project.health) ? project.health : health_options.first
  end
end
