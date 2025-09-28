module Users
  class AvatarAssetsController < ApplicationController
    before_action :set_user
    before_action :authorize_upload

    def create
      @asset = GlobalAsset.new(global_asset_params)
      @asset.uploaded_by = current_user if respond_to?(:current_user) && current_user

      if !@asset.content_type.to_s.start_with?("image/")
        @asset.errors.add(:content_type, "must be an image")
      end

      if @asset.errors.none? && @asset.save
        if @user.update(avatar_global_asset: @asset)
          redirect_to edit_user_path(@user), notice: "Avatar updated."
        else
          warnings = @user.errors.full_messages
          if warnings.any? && warnings.all? { |msg| msg =~ /Password digest can't be blank/i }
            @user.update_columns(avatar_global_asset_id: @asset.id, updated_at: Time.current)
            redirect_to edit_user_path(@user), notice: "Avatar updated."
          else
            message = warnings.to_sentence.presence || "Image uploaded, but could not assign avatar."
            redirect_to edit_user_path(@user), alert: message
          end
        end
      else
        message = @asset.errors.full_messages.to_sentence.presence || "Unable to upload image."
        redirect_to edit_user_path(@user), alert: message
      end
    end

    private

    def set_user
      @user = User.find(params[:user_id])
    end

    def global_asset_params
      params.require(:document).permit(
        :title,
        :storage_uri,
        :checksum,
        :size_bytes,
        :content_type
      ).tap do |attrs|
        attrs[:filename] = attrs.delete(:title).presence || "avatar"
        attrs[:size_bytes] = attrs[:size_bytes].to_i if attrs[:size_bytes].present?
        attrs[:storage_uri] = attrs[:storage_uri].presence
      end
    end

    def authorize_upload
      return if current_user&.admin?
      return if current_user&.planner?
      return if current_user == @user

      redirect_to edit_user_path(@user), alert: "You’re not allowed to update this avatar."
    end
  end
end
