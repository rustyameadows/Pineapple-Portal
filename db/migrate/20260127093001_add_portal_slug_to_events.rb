class AddPortalSlugToEvents < ActiveRecord::Migration[7.1]
  def change
    add_column :events, :portal_slug, :string
    add_index :events, :portal_slug, unique: true
  end
end
