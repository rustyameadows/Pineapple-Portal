module Settings
  class GlobalVendorsController < ApplicationController
    before_action :set_global_vendor, only: %i[edit update destroy]

    def index
      @global_vendors = GlobalVendor
                        .left_joins(:event_vendors)
                        .select("global_vendors.*, COUNT(event_vendors.id) AS usage_count")
                        .group("global_vendors.id")
                        .order(Arel.sql("LOWER(global_vendors.name) ASC"), :id)
    end

    def new
      @global_vendor = GlobalVendor.new
    end

    def edit; end

    def create
      @global_vendor = GlobalVendor.new(global_vendor_params)

      if @global_vendor.save
        redirect_to settings_global_vendors_path, notice: "Global vendor created."
      else
        flash.now[:alert] = @global_vendor.errors.full_messages.to_sentence
        render :new, status: :unprocessable_entity
      end
    end

    def update
      if @global_vendor.update(global_vendor_params)
        redirect_to settings_global_vendors_path, notice: "Global vendor updated."
      else
        flash.now[:alert] = @global_vendor.errors.full_messages.to_sentence
        render :edit, status: :unprocessable_entity
      end
    end

    def destroy
      if @global_vendor.event_vendors.exists?
        redirect_to settings_global_vendors_path, alert: "Cannot delete a global vendor that is linked to events."
        return
      end

      @global_vendor.destroy
      redirect_to settings_global_vendors_path, notice: "Global vendor removed."
    end

    private

    def set_global_vendor
      @global_vendor = GlobalVendor.find(params[:id])
    end

    def global_vendor_params
      params.require(:global_vendor).permit(
        :name,
        :default_vendor_type,
        :default_social_handle,
        contacts_attributes: %i[id name title email phone notes _destroy]
      )
    end
  end
end
