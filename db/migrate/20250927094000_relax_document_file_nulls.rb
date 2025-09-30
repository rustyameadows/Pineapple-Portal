class RelaxDocumentFileNulls < ActiveRecord::Migration[7.1]
  def change
    change_column_null :documents, :storage_uri, true
    change_column_null :documents, :checksum, true
    change_column_null :documents, :size_bytes, true
    change_column_null :documents, :content_type, true
  end
end
