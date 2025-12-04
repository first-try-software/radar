class Initiative
  attr_reader :name, :description, :point_of_contact

  def initialize(name:, description: '', point_of_contact: '', archived: false, related_projects_loader: nil)
    @name = name.to_s
    @description = description.to_s
    @point_of_contact = point_of_contact.to_s
    @archived = archived
    @related_projects_loader = related_projects_loader
    @related_projects = nil
  end

  def valid?
    !name.strip.empty?
  end

  def errors
    return [] if valid?

    ['name must be present']
  end

  def archived?
    !!@archived
  end

  def related_projects
    @related_projects ||= load_related_projects
  end

  private

  attr_reader :related_projects_loader

  def load_related_projects
    related_projects_loader ? Array(related_projects_loader.call(self)) : []
  end
end
