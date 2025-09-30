class AddAvatarGlobalAssetToUsers < ActiveRecord::Migration[7.1]
  def change
    add_reference :users, :avatar_global_asset, foreign_key: { to_table: :global_assets }, index: true
  end
end
