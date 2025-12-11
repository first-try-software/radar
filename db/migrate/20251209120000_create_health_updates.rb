class CreateHealthUpdates < ActiveRecord::Migration[8.1]
  def change
    create_table :health_updates, if_not_exists: true do |t|
      t.references :project, null: false, foreign_key: { to_table: :projects }
      t.date :date, null: false
      t.string :health, null: false
      t.text :description

      t.timestamps
    end

    add_index :health_updates, [:project_id, :date], if_not_exists: true
  end
end
