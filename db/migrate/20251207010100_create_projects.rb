class CreateProjects < ActiveRecord::Migration[8.1]
  def change
    create_table :projects, if_not_exists: true do |t|
      t.string :name, null: false
      t.text :description, null: false, default: ''
      t.string :point_of_contact, null: false, default: ''
      t.boolean :archived, null: false, default: false
      t.string :current_state, null: false, default: 'new'

      t.timestamps
    end

    add_index :projects, :name, unique: true, if_not_exists: true

    create_table :projects_projects, if_not_exists: true do |t|
      t.references :parent, null: false, foreign_key: { to_table: :projects }
      t.references :child, null: false, foreign_key: { to_table: :projects }
      t.integer :order, null: false

      t.timestamps
    end

    add_index :projects_projects, [:parent_id, :child_id], unique: true, if_not_exists: true
    add_index :projects_projects, [:parent_id, :order], unique: true, if_not_exists: true
    add_index :projects_projects, :child_id, unique: true, if_not_exists: true
  end
end
