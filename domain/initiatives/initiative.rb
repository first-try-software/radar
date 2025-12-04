class Initiative
  attr_reader :name, :description

  def initialize(name:, description: '', archived: false)
    @name = name.to_s
    @description = description.to_s
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
