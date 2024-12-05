# frozen_string_literal: true
require "openssl"
require "logger"
require "base64"

class Crypto
    attr_accessor :key
    attr_accessor :encrypted
    attr_accessor :cipher
    attr_accessor :key
    
    def initialize(encrypted = true)
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

        if not File.exist?("blade3.key")
            @key = @cipher.random_key

            File.binwrite("blade3.key", @key)

            @logger.debug "Wrote blade3 key to: ./blade3.key"
        else
            @key = File.binread("blade3.key")

            @logger.debug "Imported key from ./blade3.key"
        end

        @cipher.key = @key

        @cipher.iv = "0"*16
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