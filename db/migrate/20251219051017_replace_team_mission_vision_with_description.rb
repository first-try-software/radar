class ReplaceTeamMissionVisionWithDescription < ActiveRecord::Migration[8.1]
  def change
    remove_column :teams, :mission, :text
    remove_column :teams, :vision, :text
    add_column :teams, :description, :text, default: '', null: false
  end
end
