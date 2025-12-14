class CreateInitiatives < ActiveRecord::Migration[8.1]
  def change
    create_table :initiatives do |t|
      t.boolean :archived, default: false, null: false
      t.text :description, default: '', null: false
      t.string :name, null: false
      t.string :point_of_contact, default: '', null: false
      t.timestamps
    end

    add_index :initiatives, :name, unique: true

    create_table :initiatives_projects do |t|
      t.integer :initiative_id, null: false
      t.integer :project_id, null: false
      t.integer :order, null: false
      t.timestamps
    end

    add_index :initiatives_projects, :initiative_id
    add_index :initiatives_projects, :project_id, unique: true
    add_index :initiatives_projects, [:initiative_id, :project_id], unique: true
    add_index :initiatives_projects, [:initiative_id, :order], unique: true

    add_foreign_key :initiatives_projects, :initiatives
    add_foreign_key :initiatives_projects, :projects
  end
end
