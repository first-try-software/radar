class TeamsController < ApplicationController
  def show
    result = team_actions.find_team.perform(id: params[:id])

    respond_to do |format|
      format.json { render_result(result) }
      format.html do
        if result.success?
          @team = result.value
          populate_team_dashboard_data(@team)
          render :show
        else
          render file: Rails.public_path.join('404.html'), status: :not_found, layout: false
        end
      end
    end
  end

  def create
    result = team_actions.create_team.perform(**create_params)

    respond_to do |format|
      format.json { render_result(result, success_status: :created) }
      format.html do
        if result.success?
          redirect_to(team_path(result.value.id), notice: 'Team created')
        else
          redirect_to(root_path, alert: result.errors.join(', '))
        end
      end
    end
  end

  def update
    result = team_actions.update_team.perform(id: params[:id], **update_params)

    respond_to do |format|
      format.json { render_result(result) }
      format.html do
        if result.success?
          redirect_to(team_path(params[:id]), notice: 'Team updated')
        else
          @team = find_domain_team(params[:id])
          return render file: Rails.public_path.join('404.html'), status: :not_found, layout: false unless @team

          populate_team_dashboard_data(@team)
          @errors = result.errors
          render :show, status: error_status(result.errors)
        end
      end
    end
  end

  def archive
    result = team_actions.archive_team.perform(id: params[:id])

    respond_to do |format|
      format.json { render_result(result) }
      format.html do
        if result.success?
          redirect_to(team_path(params[:id]), notice: 'Team archived')
        else
          render file: Rails.public_path.join('404.html'), status: :not_found, layout: false
        end
      end
    end
  end

  def link_owned_project
    result = team_actions.link_owned_project.perform(
      team_id: params[:id],
      project_id: params[:project_id]
    )

    respond_to do |format|
      format.json { render_project_result(result, success_status: :created) }
      format.html do
        if result.success?
          redirect_to(team_path(params[:id]), notice: 'Project linked')
        else
          render file: Rails.public_path.join('404.html'), status: :not_found, layout: false
        end
      end
      format.turbo_stream do
        if result.success?
          @team = find_domain_team(params[:id])
          @project = result.value
          render :link_owned_project
        else
          render turbo_stream: turbo_stream.append("toast-container", "<div class='toast toast--error toast--visible'>Failed to link project: #{result.errors.join(', ')}</div>".html_safe), status: :unprocessable_content
        end
      end
    end
  end

  def add_owned_project
    project_name = params.dig(:project, :name)
    project_description = params.dig(:project, :description) || ''
    project_poc = params.dig(:project, :point_of_contact) || ''

    # First create the project
    create_result = project_actions.create_project.perform(
      name: project_name,
      description: project_description,
      point_of_contact: project_poc
    )
    unless create_result.success?
      respond_to do |format|
        format.json { render json: { errors: create_result.errors }, status: :unprocessable_content }
        format.html do
          @team = find_domain_team(params[:id])
          return render file: Rails.public_path.join('404.html'), status: :not_found, layout: false unless @team

          populate_team_dashboard_data(@team)
          @errors = create_result.errors
          render :show, status: :unprocessable_content
        end
        format.turbo_stream do
          render turbo_stream: turbo_stream.append("toast-container", "<div class='toast toast--error toast--visible'>Failed to create project: #{create_result.errors.join(', ')}</div>".html_safe), status: :unprocessable_content
        end
      end
      return
    end

    # Link it to the team
    link_result = team_actions.link_owned_project.perform(
      team_id: params[:id],
      project_id: create_result.value.id
    )

    respond_to do |format|
      format.json { render_project_result(link_result, success_status: :created) }
      format.html { redirect_to(team_path(params[:id]), notice: 'Project added and linked') }
      format.turbo_stream do
        @team = find_domain_team(params[:id])
        render :add_owned_project
      end
    end
  end

  def add_subordinate_team
    result = team_actions.create_subordinate_team.perform(
      parent_id: params[:id],
      name: params.dig(:team, :name),
      description: params.dig(:team, :description) || '',
      point_of_contact: params.dig(:team, :point_of_contact) || ''
    )

    respond_to do |format|
      format.json do
        if result.success?
          render json: team_json_from_domain(result.value), status: :created
        else
          render json: { errors: result.errors }, status: error_status(result.errors)
        end
      end
      format.html do
        if result.success?
          redirect_to(team_path(result.value.id), notice: 'Subordinate team created')
        else
          @team = find_domain_team(params[:id])
          return render file: Rails.public_path.join('404.html'), status: :not_found, layout: false unless @team

          populate_team_dashboard_data(@team)
          @errors = result.errors
          render :show, status: :unprocessable_content
        end
      end
      format.turbo_stream do
        if result.success?
          @team = find_domain_team(params[:id])
          render :add_subordinate_team
        else
          render turbo_stream: turbo_stream.append("toast-container", "<div class='toast toast--error toast--visible'>Failed to create team: #{result.errors.join(', ')}</div>".html_safe), status: :unprocessable_content
        end
      end
    end
  end

  private

  def team_actions
    Rails.application.config.x.team_actions
  end

  def project_actions
    Rails.application.config.x.project_actions
  end

  def find_domain_team(id)
    result = team_actions.find_team.perform(id: id)
    result.success? ? result.value : nil
  end

  def render_result(result, success_status: :ok)
    if result.success?
      render json: team_json_from_domain(result.value), status: success_status
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
    errors = Array(errors)
    return :not_found if errors.include?('team not found')
    return :not_found if errors.include?('project not found')

    :unprocessable_content
  end

  def team_json_from_domain(team)
    {
      name: team.name,
      description: team.description,
      point_of_contact: team.point_of_contact,
      archived: team.archived?
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
    permitted = params.fetch(:team, {}).permit(:name, :description, :point_of_contact).to_h.symbolize_keys
    permitted[:name] ||= ''
    permitted[:description] ||= ''
    permitted[:point_of_contact] ||= ''
    permitted
  end

  def update_params
    params.fetch(:team, {}).permit(:name, :description, :point_of_contact).to_h.symbolize_keys
  end

  def populate_team_dashboard_data(team)
    health_update_repo = Rails.application.config.x.health_update_repository

    dashboard = TeamDashboard.new(
      team: team,
      health_update_repository: health_update_repo,
      current_date: Date.current
    )

    @health_summary = dashboard.health_summary

    # Global search data
    @teams = team_repository.all_active_roots
    @initiatives = initiative_repository.all_active_roots
    @all_projects = project_repository.all_active_roots

    # Trend data
    trend_service = TeamTrendService.new(
      team: team,
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
    build_team_presenters(team)
  end

  def build_team_presenters(team)
    # Header presenter
    @header_presenter = TeamHeaderPresenter.new(
      entity: team,
      view_context: view_context
    )

    # Metric presenters
    leaf_projects = team.all_leaf_projects
    active_leaves = leaf_projects.select { |p| [:in_progress, :blocked].include?(p.current_state) }
    off_track_count = active_leaves.count { |p| p.health == :off_track }
    at_risk_count = active_leaves.count { |p| p.health == :at_risk }

    @health_presenter = HealthPresenter.new(
      health: team.health,
      raw_score: @health_summary[:raw_score],
      off_track_count: off_track_count,
      at_risk_count: at_risk_count,
      total_count: active_leaves.size,
      methodology: "Weighted average of leaf project health scores."
    )

    @trend_presenter = TrendPresenter.new(
      trend_data: @trend_data,
      trend_direction: @trend_direction,
      trend_delta: @trend_delta,
      weeks_of_data: @weeks_of_data,
      gradient_id: "team-trend-gradient"
    )

    @confidence_presenter = ConfidencePresenter.new(
      score: @confidence_score,
      level: @confidence_level,
      factors: @confidence_factors
    )

    # Edit modal presenter
    @edit_modal_presenter = TeamEditModalPresenter.new(
      entity: team,
      view_context: view_context
    )

    # Search data
    build_search_data
  end

  def build_search_data
    @search_teams = []
    build_team_tree = ->(teams) do
      teams.sort_by(&:name).each do |t|
        @search_teams << { entity: t }
        build_team_tree.call(t.subordinate_teams) if t.subordinate_teams.any?
      end
    end
    build_team_tree.call(@teams)

    @search_initiatives = @initiatives.map do |initiative|
      { entity: initiative }
    end

    @search_projects = @all_projects.map do |project|
      { entity: project }
    end
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
