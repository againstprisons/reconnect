require 'mimemagic'
require 'mimemagic/overlay'
require 'digest'

class ReConnect::Models::File < Sequel::Model
  def self.upload(data, opts = {})
    fileid = ReConnect::Crypto.generate_token
    obj = self.new(file_id: fileid, creation: DateTime.now)
    obj.replace(opts[:filename], data)
    obj.save

    obj
  end
  
  def replace(filename, data)
    mime = MimeMagic.by_magic(data)
    unless filename
      filename = "unknown"
      if mime && mime.extensions.count.positive?
        filename = "#{filename}.#{mime.extensions.first}"
      end
    end
    
    # Encrypt file
    encrypted = ReConnect::Crypto.encrypt("file", self.file_id, nil, data)

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
    
    self.file_hash = digest
    self.mime_type = mime
    self.original_fn = filename
  end

  def generate_download_token(user)
    user = user.id if user.respond_to?(:id)

    token = ReConnect::Models::Token.generate
    token.expiry = Time.now + (60 * 60) # expire in an hour
    token.user_id = user
    token.use = "file_download"
    token.extra_data = self.file_id
    token.save

    token
  end

  def generate_fn
    if self.mime_type
      mime = MimeMagic.new(self.mime_type)
      ext = mime.extensions.first
    end

    fn = self.creation.strftime("%Y-%m-%d_%H%M%S_%s")
    if ext
      fn += ".#{ext}"
    end

    fn
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
