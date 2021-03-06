class CreateProjectRoles < ActiveRecord::Migration[4.2]
  def change
    create_table :project_roles, id: false do |t|
      t.string :id, null: false
      t.string :name
      t.string :description
      t.boolean :is_deprecated, null: false, default: false

      t.timestamps null: false
    end
  end
end
