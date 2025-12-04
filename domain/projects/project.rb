class Project
  attr_reader :name, :description, :point_of_contact

  def initialize(name:, description: '', point_of_contact: '', archived: false, subordinates_loader: nil)
    @name = name.to_s
    @description = description.to_s
    @point_of_contact = point_of_contact.to_s
    @archived = archived
    @subordinates_loader = subordinates_loader
    @subordinate_projects = nil
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

  def subordinate_projects
    @subordinate_projects ||= load_subordinates
  end

  private

  attr_reader :subordinates_loader

  def load_subordinates
    return [] unless subordinates_loader

    subordinates_loader.call(self)
  end
end
