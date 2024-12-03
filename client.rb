# frozen_string_literal: true
require "logger"
require "socket"
require "./crypto.rb"
require "./packet.rb"

class Client
  attr_accessor :is_encrypted
  def initialize(address, port)
    @logger = Logger.new(STDOUT)

    @address = address
    @port = port
  end

  def mainloop
    @logger.info "Creating inbound, and outbound encryption modules"
    @inbound_crypto = Crypto.new(false)
    @outbound_crypto = Crypto.new()

    @logger.info "Connecting to remote: #{@address}:#{@port}"

    @remote = TCPSocket.new(@address, @port)

    while (packet = @remote.gets("\0"))
      unless @is_encrypted
        @logger.debug "Got welcome packet of: #{packet}"

        @is_encrypted = true

        next
      end

      decrypted = @inbound_crypto.decrypt(packet)

      @logger.debug "Got packet: #{decrypted}"
      packet = Packet.new()
      packet.from_json(decrypted)

      if packet.packet_type == PacketType::TEST_ENCRYPTION
        if packet.body["test1"] != "I am a teapot. Encryption works"
          raise "Encryption Error. Decrypted packet does not have the magic message!"
        else
          @logger.info "Encryption works. Tunnel secure!"
        end
      end
    end
  end

end