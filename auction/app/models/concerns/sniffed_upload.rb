# Active Storage (Marcel) trusts the filename extension when the bytes carry no signature, so a text file
# named photo.png would be stored as image/png. For new uploads we look at the bytes only.
module SniffedUpload
  extend ActiveSupport::Concern

  # Real type of the attached file, from its content and not from its name or the browser header.
  def sniffed_content_type
    attachable = attachment_changes["file"]&.attachable
    io = attachable.respond_to?(:tempfile) ? attachable.tempfile : (attachable[:io] if attachable.is_a?(Hash))
    return file.blob&.content_type unless io

    io.rewind
    Marcel::MimeType.for(io).tap { io.rewind }
  end
end
