class PasswordResetToken < ApplicationRecord
  DEFAULT_TTL = 30.days

  belongs_to :user
  belongs_to :issued_by, class_name: "User", optional: true

  validates :token, presence: true, uniqueness: true
  validates :expires_at, presence: true

  scope :active, -> { where(redeemed_at: nil).where("expires_at > ?", Time.current) }
  scope :most_recent_first, -> { order(created_at: :desc) }

  def self.generate_for!(user:, issued_by: nil, ttl: DEFAULT_TTL)
    transaction do
      user.password_reset_tokens.active.update_all(expires_at: Time.current)
      create!(
        user: user,
        issued_by: issued_by,
        token: SecureRandom.urlsafe_base64(32),
        expires_at: ttl.from_now
      )
    end
  end

  def expired?
    expires_at <= Time.current
  end

  def redeem!
    update!(redeemed_at: Time.current)
  end
end
