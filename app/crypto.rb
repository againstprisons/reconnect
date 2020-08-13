require 'rack'
require 'rbnacl'
require 'typhoeus'
require 'memoist'

module ReConnect::Crypto
  TOKEN_LENGTH = 32
  OPS_LIMIT = 2**20
  MEM_LIMIT = 2**24

  class << self
    extend Memoist

    def keyderiv_url
      unless ENV.key?("KEYDERIV_URL")
        raise RuntimeError, "KEYDERIV_URL not specified in environment"
      end

      return ENV["KEYDERIV_URL"]
    end

    def keyderiv_secret
      unless ENV.key?("KEYDERIV_SECRET")
        raise RuntimeError, "KEYDERIV_SECRET not specified in environment"
      end

      return ReConnect::Utils.hex_to_bin(ENV["KEYDERIV_SECRET"])
    end

    memoize :keyderiv_url, :keyderiv_secret

    #####
    # Encryption/decryption
    #####

    def get_encryption_key(table, column, row)
      box = RbNaCl::SecretBox.new(self.keyderiv_secret)
      nonce = RbNaCl::Random.random_bytes(box.nonce_bytes)

      body = {
        "mode" => "encrypt",
        "table" => table.to_s,
        "column" => column.to_s,
        "row" => row.to_s,
        "nonce" => ReConnect::Utils.bin_to_hex(nonce),
      }

      out = Typhoeus.get(self.keyderiv_url, :method => :post, :body => body)
      raise "Non-200 from keyderiv" unless out.response_code == 200

      return box.decrypt(nonce, ReConnect::Utils.hex_to_bin(out.body.strip))
    end

    memoize :get_encryption_key

    def decrypt(table, column, row, data, opts = {})
      return "" unless data

      encoding = opts[:encoding] || Encoding::UTF_8
      data = ReConnect::Utils.hex_to_bin(data)
      key = self.get_encryption_key(table, column, row)
      box = RbNaCl::SecretBox.new(ReConnect::Utils.hex_to_bin(key))

      nonce = data[0..(box.nonce_bytes - 1)]
      data = data[(box.nonce_bytes)..(data.length)]
      decrypted = box.decrypt(nonce, data)

      return decrypted.force_encoding(encoding)
    end

    def encrypt(table, column, row, data)
      return nil if data.nil?

      key = self.get_encryption_key(table, column, row)
      box = RbNaCl::SecretBox.new(ReConnect::Utils.hex_to_bin(key))

      nonce = RbNaCl::Random.random_bytes(box.nonce_bytes)
      return ReConnect::Utils.bin_to_hex(nonce + box.encrypt(nonce, data))
    end

    #####
    # Indexes
    #####

    def get_index_key(table, column)
      box = RbNaCl::SecretBox.new(self.keyderiv_secret)
      nonce = RbNaCl::Random.random_bytes(box.nonce_bytes)

      body = {
        "mode" => "index",
        "table" => table.to_s,
        "column" => column.to_s,
        "nonce" => ReConnect::Utils.bin_to_hex(nonce),
      }

      out = Typhoeus.get(self.keyderiv_url, :method => :post, :body => body)
      raise "Non-200 from keyderiv" unless out.response_code == 200
      return box.decrypt(nonce, ReConnect::Utils.hex_to_bin(out.body.strip))
    end

    memoize :get_index_key

    def index(table, column, data)
      key = self.get_index_key(table, column)
      index = RbNaCl::PasswordHash.scrypt(data, ReConnect::Utils.hex_to_bin(key), OPS_LIMIT, MEM_LIMIT, 64)
      return ReConnect::Utils.bin_to_hex(index)
    end

    #####
    # Password hashing
    #####

    def password_hash(password, salt=nil)
      unless salt
        saltbytes = RbNaCl::PasswordHash::SCrypt::SALTBYTES
        salt = RbNaCl::Random.random_bytes(saltbytes)
      end

      hash = RbNaCl::PasswordHash.scrypt(password, salt, OPS_LIMIT, MEM_LIMIT, 64)

      return ReConnect::Utils.bin_to_hex(salt + hash)
    end

    def password_verify(hashed, password)
      saltbytes = RbNaCl::PasswordHash::SCrypt::SALTBYTES
      data = ReConnect::Utils.hex_to_bin(hashed)
      return false if data.nil? || data&.empty?
      salt = data[0..(saltbytes - 1)]

      return Rack::Utils.secure_compare(hashed, self.password_hash(password, salt))
    end

    #####
    # Token generation
    #####

    def generate_token
      return ReConnect::Utils.bin_to_hex(RbNaCl::Random.random_bytes(TOKEN_LENGTH))
    end
  end
end
