# frozen_string_literal: true

class GraphBackgroundUploader < CarrierWave::Uploader::Base
  include CarrierWave::MiniMagick
  include CarrierWave::BombShelter

  # def background_type_whitelist
  #  [:jpeg, :png]
  # end

  # Choose what kind of storage to use for this uploader:
  storage :file
  # storage :fog

  # Override the directory where uploaded files will be stored.
  # This is a sensible default for uploaders that are meant to be mounted:
  def store_dir
    "uploads/#{model.class.to_s.underscore}/#{mounted_as}/#{model.id}"
  end

  # Create different versions of your uploaded files:
  version :show do
    process resize_to_limit: [360, 360]
  end

  # Add a white list of extensions which are allowed to be uploaded.
  # For images you might use something like this:
  def extension_white_list
    %w[jpg jpeg png]
  end
end
