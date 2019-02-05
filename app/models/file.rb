require 'mimemagic'
require 'mimemagic/overlay'
require 'digest'

class ReConnect::Models::File < Sequel::Model
  def self.upload(data, opts = {})
    filename = opts[:filename]

    fileid = ReConnect::Crypto.generate_token
    mime = MimeMagic.by_magic(data)

    # Encrypt file
    encrypted = ReConnect::Crypto.encrypt("file", fileid, nil, data)

    # Hash it
    digest = Digest::SHA512.hexdigest(encrypted)

    # Get paths
    dirname = File.join(ReConnect.app_config["file-storage-dir"], digest[0..1])
    filepath = File.join(dirname, digest)
    raise "A duplicate file already exists." if File.exist?(filepath)

    # Create dir to hold file if it doesn't already exist
    Dir.mkdir(dirname) unless Dir.exist?(dirname)

    # Save file
    File.open(filepath, "wb+") do |f|
      f.write(encrypted)
    end

    obj = self.new({
      :file_id => fileid,
      :creation => DateTime.now,
      :file_hash => digest,
      :mime_type => mime,
      :original_fn => filename,
    })

    obj.save
    obj
  end

  def generate_fn
    mime = MimeMagic.new(self.mime_type)
    ext = mime.extensions.first

    "#{self.creation.strftime("%Y-%m-%d_%H%M%S_%s")}.#{ext}"
  end

  def abspath
    digest = self.file_hash
    File.join(ReConnect.app_config["file-storage-dir"], digest[0..1], digest)
  end

  def decrypt_file
    data = File.open(self.abspath, "rb") do |f|
      f.read
    end

    ReConnect::Crypto.decrypt("file", self.file_id, nil, data)
  end

  def delete!
    File.unlink(self.abspath)
    self.delete
  end
end
