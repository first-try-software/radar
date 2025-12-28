class InitiativesController < ApplicationController
  def show
    result = initiative_actions.find_initiative.perform(id: params[:id])

    respond_to do |format|
      format.json { render_result(result) }
      format.html do
        if result.success?
          @initiative = result.value
          @initiative_record = InitiativeRecord.find(params[:id])
          populate_dashboard_data(@initiative)
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
          redirect_to(initiative_path(result.value.id), notice: 'Initiative created')
        else
          redirect_to(root_path, alert: result.errors.join(', '))
        end
      end
    end
  end

  def update
    result = initiative_actions.update_initiative.perform(id: params[:id], **update_params)

    respond_to do |format|
      format.json { render_result(result) }
      format.html do
        if result.success?
          redirect_to(initiative_path(params[:id]), notice: 'Initiative updated')
        else
          @initiative_record = InitiativeRecord.find(params[:id])
          @initiative = result.value || find_domain_initiative(@initiative_record.id)
          @errors = result.errors
          populate_dashboard_data(@initiative)
          render :show, status: error_status(result.errors)
        end
      end
    end
  end

  def set_state
    cascade = params[:cascade] == 'true' || params[:cascade] == true
    result = initiative_actions.set_initiative_state.perform(
      id: params[:id],
      state: params[:state],
      cascade: cascade
    )

    respond_to do |format|
      format.json do
        if result.success?
          render json: initiative_json(result.value), status: :ok
        else
          render json: { errors: result.errors }, status: error_status(result.errors)
        end
      end
      format.html do
        if result.success?
          redirect_to(initiative_path(params[:id]), notice: 'State updated')
        else
          render file: Rails.public_path.join('404.html'), status: :not_found, layout: false
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
      format.turbo_stream do
        if result.success?
          @initiative = find_domain_initiative(params[:id])
          @initiative_record = InitiativeRecord.find(params[:id])
          @linked_project = result.value
          render :link_related_project
        else
          render turbo_stream: turbo_stream.append("toast-container", "<div class='toast toast--error toast--visible'>Failed to link project: #{result.errors.join(', ')}</div>".html_safe), status: :unprocessable_content
        end
      end
    end
  end

  def add_related_project
    project_name = params.dig(:project, :name)

    # First create the project
    create_result = project_actions.create_project.perform(name: project_name)
    unless create_result.success?
      respond_to do |format|
        format.json { render json: { errors: create_result.errors }, status: :unprocessable_content }
        format.html do
          @initiative_record = InitiativeRecord.find(params[:id])
          @initiative = find_domain_initiative(@initiative_record.id)
          @errors = create_result.errors
          populate_dashboard_data(@initiative)
          render :show, status: :unprocessable_content
        end
        format.turbo_stream do
          render turbo_stream: turbo_stream.append("toast-container", "<div class='toast toast--error toast--visible'>Failed to create project: #{create_result.errors.join(', ')}</div>".html_safe), status: :unprocessable_content
        end
      end
      return
    end

    # Find the created project record
    project_record = ProjectRecord.find_by(name: project_name)

    # Link it to the initiative
    link_result = initiative_actions.link_related_project.perform(
      initiative_id: params[:id],
      project_id: project_record.id
    )

    respond_to do |format|
      format.json { render_project_result(link_result, success_status: :created) }
      format.html do
        if link_result.success?
          redirect_to(initiative_path(params[:id]), notice: 'Project added and linked')
        else
          @initiative_record = InitiativeRecord.find(params[:id])
          @initiative = find_domain_initiative(@initiative_record.id)
          @errors = link_result.errors
          populate_dashboard_data(@initiative)
          render :show, status: :unprocessable_content
        end
      end
      format.turbo_stream do
        if link_result.success?
          @initiative = find_domain_initiative(params[:id])
          @initiative_record = InitiativeRecord.find(params[:id])
          render :add_related_project
        else
          render turbo_stream: turbo_stream.append("toast-container", "<div class='toast toast--error toast--visible'>Failed to link project: #{link_result.errors.join(', ')}</div>".html_safe), status: :unprocessable_content
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

  def project_actions
    Rails.application.config.x.project_actions
  end

  def find_domain_initiative(id)
    result = initiative_actions.find_initiative.perform(id: id)
    result.success? ? result.value : nil
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
      current_state: initiative.current_state.to_s,
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

  def populate_dashboard_data(initiative)
    return set_empty_dashboard_data unless initiative

    health_update_repo = Rails.application.config.x.health_update_repository

    dashboard = InitiativeDashboard.new(
      initiative: initiative,
      health_update_repository: health_update_repo,
      current_date: Date.current
    )

    @health_summary = dashboard.health_summary
    @total_active_projects = dashboard.total_active_projects
    @attention_required = dashboard.attention_required
    @on_hold_projects = dashboard.on_hold_projects
    @never_updated_projects = dashboard.never_updated_projects
    @stale_projects_14 = dashboard.stale_projects(days: 14)
    @stale_projects_7 = dashboard.stale_projects_between(min_days: 7, max_days: 14)

    # Global search data
    @teams = team_repository.all_active_roots
    @initiatives = initiative_repository.all_active_roots
    @all_projects = project_repository.all_active_roots

    # Trend data
    trend_service = InitiativeTrendService.new(
      initiative: initiative,
      health_update_repository: health_update_repo,
      current_date: Date.current
    )
    trend_result = trend_service.call

    @trend_data = trend_result[:trend_data]
    @trend_direction = trend_result[:trend_direction]
    @trend_delta = trend_result[:trend_delta]
    @weeks_of_data = trend_result[:weeks_of_data]
    @confidence_score = trend_result[:confidence_score]
    @confidence_level = trend_result[:confidence_level]
    @confidence_factors = trend_result[:confidence_factors] || {}

    # Build presenters for shared partials
    build_initiative_presenters(initiative)
  end

  def build_initiative_presenters(initiative)
    # Header presenter
    @header_presenter = InitiativeHeaderPresenter.new(
      entity: initiative,
      record: @initiative_record,
      view_context: view_context
    )

    # Metric presenters
    leaf_projects = initiative.leaf_projects
    active_leaves = leaf_projects.select { |p| [:in_progress, :blocked].include?(p.current_state) }
    off_track_count = active_leaves.count { |p| p.health == :off_track }
    at_risk_count = active_leaves.count { |p| p.health == :at_risk }

    @health_presenter = HealthPresenter.new(
      health: initiative.health,
      raw_score: @health_summary[:raw_score],
      off_track_count: off_track_count,
      at_risk_count: at_risk_count,
      total_count: active_leaves.size,
      methodology: "Weighted average of related project health scores."
    )

    @trend_presenter = TrendPresenter.new(
      trend_data: @trend_data,
      trend_direction: @trend_direction,
      trend_delta: @trend_delta,
      weeks_of_data: @weeks_of_data,
      gradient_id: "initiative-trend-gradient"
    )

    @confidence_presenter = ConfidencePresenter.new(
      score: @confidence_score,
      level: @confidence_level,
      factors: @confidence_factors
    )

    # Edit modal presenter
    @edit_modal_presenter = InitiativeEditModalPresenter.new(
      entity: initiative,
      record: @initiative_record,
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

    @search_projects = @all_projects.map do |project|
      { entity: project, record: ProjectRecord.find_by(name: project.name) }
    end
  end

  def set_empty_dashboard_data
    @health_summary = { on_track: 0, at_risk: 0, off_track: 0 }
    @total_active_projects = 0
    @attention_required = []
    @on_hold_projects = []
    @never_updated_projects = []
    @stale_projects_14 = []
    @stale_projects_7 = []
    @teams = []
    @initiatives = []
    @all_projects = []
    @trend_data = []
    @trend_direction = :stable
    @trend_delta = 0.0
    @weeks_of_data = 0
    @confidence_score = 0
    @confidence_level = :low
    @confidence_factors = { biggest_drag: :insufficient_data, details: {} }

    # Build empty presenters to avoid nil errors
    @header_presenter = InitiativeHeaderPresenter.new(
      entity: nil,
      record: @initiative_record,
      view_context: view_context
    )
    @health_presenter = HealthPresenter.new(
      health: :not_available,
      methodology: :initiative_rollup
    )
    @trend_presenter = TrendPresenter.new(
      trend_data: [],
      trend_direction: :stable,
      trend_delta: 0.0,
      weeks_of_data: 0
    )
    @confidence_presenter = ConfidencePresenter.new(
      score: 0,
      level: :low,
      factors: {}
    )
    @edit_modal_presenter = InitiativeEditModalPresenter.new(
      entity: nil,
      record: @initiative_record,
      view_context: view_context
    )
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

end
