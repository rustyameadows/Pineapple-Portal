class AddSegmentCacheFields < ActiveRecord::Migration[7.1]
  def change
    change_table :document_segments, bulk: true do |t|
      t.string :render_hash
      t.string :cached_pdf_key
      t.datetime :cached_pdf_generated_at
      t.integer :cached_page_count
      t.integer :cached_file_size
      t.string :last_render_error
    end

    add_index :document_segments, :render_hash
  end
end
