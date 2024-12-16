# frozen_string_literal: true
require "openssl"
require "logger"
require "base64"

class Crypto
    attr_accessor :key
    attr_accessor :encrypted
    attr_accessor :cipher
    attr_accessor :key
    attr_accessor :iv
    
    def initialize(encrypted = true, iv = "no")
        @encrypted = encrypted

        @logger = Logger.new(STDOUT)

        @mutex = Mutex.new

        @logger.info "Initializing encryption using AES-256-CBC"

        @cipher = OpenSSL::Cipher.new("aes-256-cbc")
        if encrypted
            @cipher.encrypt
        else
            @cipher.decrypt
        end

        if not File.exist?("/etc/blade3/crypto/blade3.key")
            @key = @cipher.random_key

            File.binwrite("/etc/blade3/crypto/blade3.key", @key)

            @logger.debug "Wrote blade3 key to: /etc/blade3/crypto/blade3.key"
        else
            @key = File.binread("/etc/blade3/crypto/blade3.key")

            @logger.debug "Imported key from /etc/blade3/crypto/blade3.key"
        end

        @cipher.key = @key

        if iv == "no" then
            @iv = @cipher.random_iv
        else
            @iv = iv
        end
        
        @cipher.iv = @iv
    end

    def encrypt(message)
        unless @encrypted
            raise "Encryption disabled for this Crypto instance!"
        end

        @mutex.synchronize {

            final = Base64::encode64(@cipher.update(message) + @cipher.final)

            @cipher.reset

            final
        }
    end

    def decrypt(message)
        if @encrypted
            raise "Encryption enabled for this Crypto instance!"
        end

        @mutex.synchronize {
            final = @cipher.update(Base64::decode64(message)) + @cipher.final

            @cipher.reset

            final
        }
    end
end
