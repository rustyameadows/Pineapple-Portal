class CreatePasswordResetTokens < ActiveRecord::Migration[7.1]
  def change
    create_table :password_reset_tokens do |t|
      t.references :user, null: false, foreign_key: true
      t.references :issued_by, null: true, foreign_key: { to_table: :users }
      t.string :token, null: false
      t.datetime :expires_at, null: false
      t.datetime :redeemed_at

      t.timestamps
    end

    add_index :password_reset_tokens, :token, unique: true
    add_index :password_reset_tokens, :expires_at
  end
end
