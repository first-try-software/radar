class Project
  attr_reader :name, :description, :point_of_contact

  def initialize(name:, description: '', point_of_contact: '', archived: false)
    @name = name.to_s
    @description = description.to_s
    @point_of_contact = point_of_contact.to_s
    @archived = archived
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

end
