class AddGeneratedCompileMetadata < ActiveRecord::Migration[7.1]
  def change
    change_table :documents, bulk: true do |t|
      t.integer :compiled_page_count unless column_exists?(:documents, :compiled_page_count)
    end
  end
end
