class AddPacketContainerKindToDocuments < ActiveRecord::Migration[8.0]
  def change
    add_column :documents, :packet_container_kind, :string, null: false, default: "packet"
    add_index :documents, :packet_container_kind
  end
end
