class RemoveProjectUniqueConstraintFromInitiativesProjects < ActiveRecord::Migration[8.1]
  def change
    remove_index :initiatives_projects, :project_id
    add_index :initiatives_projects, :project_id
  end
end
