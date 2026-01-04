class ProjectHierarchy
  STATE_PRIORITY = [:blocked, :in_progress, :on_hold, :todo, :new, :done].freeze

  def initialize(children_loader:, parent_loader:, owner: nil)
    @children_loader = children_loader
    @parent_loader = parent_loader
    @owner = owner
    @children = nil
    @parent = nil
  end

  def children
    @children ||= Array(children_loader&.call)
  end

  def parent
    @parent ||= parent_loader&.call
  end

  def leaf?
    children.empty?
  end

  def leaf_descendants
    return [owner] if leaf?

    children.flat_map(&:leaf_descendants)
  end

  def derived_state
    leaves = leaf_descendants
    return :new if leaves.empty?

    leaf_states = leaves.map(&:current_state)
    STATE_PRIORITY.find { |state| leaf_states.include?(state) } || :new
  end

  private

  attr_reader :children_loader, :parent_loader, :owner
end
