# frozen_string_literal: true

class LogoUploader < CarrierWave::Uploader::Base
  include CarrierWave::MiniMagick
  include CarrierWave::BombShelter

  def image_type_whitelist
    %i[jpeg png gif]
  end

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
    process :crop
    process resize_to_limit: [200, 200]
  end

  version :preview do
    process resize_to_limit: [400, 400]
  end

  version :print do
    process :crop
    process resize_and_pad: [200, 200]
    process convert: [:png]
    def full_filename(for_file)
      parent_name = super(for_file)
      ext         = File.extname(parent_name)
      base_name   = parent_name.chomp(ext)
      "#{[base_name, version_name].compact.join('_')}.png"
    end
  end

  def crop
    return unless model.crop_x.present?

    resize_to_limit(400, 400)
    manipulate! do |img|
      x = model.crop_x
      y = model.crop_y
      w = model.crop_w
      h = model.crop_h

      img.combine_options do |c|
        c.crop("#{w}x#{h}+#{x}+#{y}").repage.+
      end

      img
    end
  end

  # Add a white list of extensions which are allowed to be uploaded.
  # For images you might use something like this:
  def extension_white_list
    %w[jpg jpeg gif png]
  end
end
