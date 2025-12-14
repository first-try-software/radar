ProjectLoaders = Data.define(
  :children,
  :parent,
  :health_updates,
  :weekly_health_updates
) do
  def initialize(
    children: nil,
    parent: nil,
    health_updates: nil,
    weekly_health_updates: nil
  )
    super
  end
end
