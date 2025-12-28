module ApplicationHelper
  def sort_projects_canonical(projects)
    ProjectSorter.new(projects).sorted
  end

  # Breadcrumb helpers

  def project_breadcrumb(project)
    crumbs = [{ name: 'Radar', path: root_path }]

    # Collect project ancestors
    project_ancestors = collect_project_ancestors(project)

    # Find owning team from root ancestor or current project
    root_project = project_ancestors.last || project
    if root_project.owning_team
      team_crumbs = build_team_hierarchy_crumbs(root_project.owning_team)
      crumbs.concat(team_crumbs)
    end

    # Add project hierarchy (parents) in root-first order
    project_ancestors.reverse.each do |ancestor|
      crumbs << { name: ancestor.name, path: project_path(ancestor.id) }
    end

    render_breadcrumb(crumbs)
  end

  def team_breadcrumb(team)
    crumbs = [{ name: 'Radar', path: root_path }]

    # Add parent team hierarchy
    if team.parent_team
      parent_crumbs = build_team_hierarchy_crumbs(team.parent_team)
      crumbs.concat(parent_crumbs)
    end

    render_breadcrumb(crumbs)
  end

  def initiative_breadcrumb(initiative)
    crumbs = [{ name: 'Radar', path: root_path }]
    render_breadcrumb(crumbs)
  end

  def trend_arrow_svg(direction)
    case direction
    when :up
      '<svg class="trend-arrow trend-arrow--up" viewBox="0 0 16 16" fill="currentColor"><path d="M8 3L14 11H2L8 3Z"/></svg>'.html_safe
    when :down
      '<svg class="trend-arrow trend-arrow--down" viewBox="0 0 16 16" fill="currentColor"><path d="M8 13L2 5H14L8 13Z"/></svg>'.html_safe
    else
      '<svg class="trend-arrow trend-arrow--stable" viewBox="0 0 16 16" fill="currentColor"><path d="M13 7L13 9L3 9L3 7L13 7Z"/></svg>'.html_safe
    end
  end

  def home_icon_svg
    '<svg class="breadcrumb__home-icon" viewBox="0 0 16 16" fill="currentColor"><path d="M8 1L1 7h2v7h4v-4h2v4h4V7h2L8 1z"/></svg>'.html_safe
  end

  private

  def build_team_hierarchy_crumbs(team)
    crumbs = []
    current = team

    # Collect ancestors
    ancestors = []
    while current
      ancestors << current
      current = current.parent_team
    end

    # Reverse to get root-first order
    ancestors.reverse.each do |t|
      crumbs << { name: t.name, path: team_path(t.id) }
    end

    crumbs
  end

  def collect_project_ancestors(project)
    ancestors = []
    current = project.parent

    while current
      ancestors << current
      current = current.parent
    end

    ancestors
  end

  def render_breadcrumb(crumbs)
    return ''.html_safe if crumbs.empty?

    last_index = crumbs.length - 1

    links = crumbs.each_with_index.map do |crumb, index|
      if index == 0 && crumb[:name] == 'Radar'
        # First crumb is home - use house icon
        link_to(home_icon_svg, crumb[:path], class: 'breadcrumb__link breadcrumb__link--home', aria: { label: 'Home' })
      elsif index == last_index
        # Last crumb shows full text
        link_to(crumb[:name], crumb[:path], class: 'breadcrumb__link')
      else
        # Middle crumbs show initials with ellipsis
        initials = crumb[:name].split.map { |word| word[0] }.join
        link_to("#{initials}…", crumb[:path], class: 'breadcrumb__link', title: crumb[:name])
      end
    end

    content_tag(:nav, class: 'breadcrumb', aria: { label: 'Breadcrumb' }) do
      safe_join(links, content_tag(:span, ' / ', class: 'breadcrumb__separator'))
    end
  end
end
