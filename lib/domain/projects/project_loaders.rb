ProjectLoaders = Data.define(
  :children,
  :parent,
  :health_updates,
  :weekly_health_updates,
  :owning_team
) do
  def initialize(
    children: nil,
    parent: nil,
    health_updates: nil,
    weekly_health_updates: nil,
    owning_team: nil
  )
    super
  end
end
