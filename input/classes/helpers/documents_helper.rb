# frozen_string_literal: true

module DocumentsHelper
  # rubocop:disable Metrics/CyclomaticComplexity
  # rubocop:disable Metrics/PerceivedComplexity
  def document_icon_url(document)
    if document.is_msword?
      image_path "referential/file-word.svg"
    elsif document.is_pdf?
      image_path "referential/file-pdf.svg"
    elsif document.is_excel?
      image_path "referential/file-excel.svg"
    elsif document.is_ppt?
      image_path "referential/file-power.svg"
    elsif document.is_image?
      image_path "referential/file-image.svg"
    elsif document.is_domainURL?
      image_path "referential/file-url.svg"
    elsif document.is_audio?
      image_path "referential/file-sound.svg"
    elsif document.is_video?
      image_path "referential/file-video.svg"
    else
      image_path "referential/file-other.svg"
    end
  end
  # rubocop:enable Metrics/CyclomaticComplexity
  # rubocop:enable Metrics/PerceivedComplexity
end
