# frozen_string_literal: true
require "logger"
require "socket"
require "./crypto.rb"
require "./packet.rb"
require "./config.rb"

class Client
  attr_accessor :is_encrypted
  attr_accessor :ports
  attr_accessor :port


  def initialize(address, port)
    @logger = Logger.new(STDOUT)

    @address = address
    @port = port
    @active_client_list = Hash.new
  end

  def run_rc
    @logger.info "Running ./user/blade3_client_init.rb"

    require "./user/blade3_client_init.rb"
    @ports = UserConfigInit.new.get_ports
  end

  def send_outbound(message)
    @remote.print @outbound_crypto.encrypt(message.to_json) + "\0"
  end

  def forward_remote_ports
    @ports.each { |port|
      @logger.debug "Forwarding #{port}"

      forward_msg = Packet.new()
      forward_msg.packet_type = PacketType::CONFIGURE_ADD_PORT
      forward_msg.body = port

      send_outbound(forward_msg)
    }
  end

  def handle_new_client(packet)
    Thread.start do
      @logger.debug "Handling new remote connection with ID #{packet.body["connection_id"]} for port #{packet.body["port"]}"

      connection_id = packet.body["connection_id"]

      stream = TCPSocket.new("0.0.0.0", packet.body["port"])

      @active_client_list[packet.body["connection_id"]] = stream

      while (line = stream.recv(1024))
        # Forward packet to the remote server
        tcp_forward_packet = Packet.new
        tcp_forward_packet.packet_type = PacketType::TCP_FORWARD
        tcp_forward_packet.body = {
          connection_id: connection_id,
          line: Base64.encode64(line)
        }

        send_outbound(tcp_forward_packet)
      end

      # Disconnected
      @logger.debug "Local connection closed on port #{packet.body["port"]}"

      tcp_closed_packet = Packet.new
      tcp_closed_packet.packet_type = PacketType::TCP_CLOSE
      tcp_closed_packet.body = {
        connection_id: connection_id,
      }

      send_outbound(tcp_closed_packet)
    end
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

      packet = Packet.new
      packet.from_json(decrypted)

      if packet.packet_type == PacketType::TEST_ENCRYPTION
        if packet.body["test1"] != "I am a teapot. Encryption works"
          raise "Encryption Error. Decrypted packet does not have the magic message!"
        else
          @logger.info "Encryption works. Tunnel secure!"
          run_rc

          @logger.info "Forwarding ports to remote..."
          forward_remote_ports
        end
      end

      if packet.packet_type == PacketType::TCP_OPEN
        handle_new_client(packet)
      end

      if packet.packet_type == PacketType::TCP_FORWARD
        if not @active_client_list.has_key?(packet.body["connection_id"])
          @logger.warn "Failed to forward packet! Connection ID invalid"
        else
          @active_client_list[packet.body["connection_id"]].print Base64.decode64(packet.body["line"])
        end
      end
    end
  end

end