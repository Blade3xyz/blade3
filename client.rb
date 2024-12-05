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
    @is_encrypted = false

    @open_clients = Hash.new
  end

  def run_rc
    @logger.info "Running ./user/blade3_client_init.rb"

    require "./user/blade3_client_init.rb"
    @ports = UserConfigInit.new.get_ports
  end

  def send_outbound(message)
    final = @outbound_crypto.encrypt(message.to_json)
    final.gsub!("\n", "\0")

    @remote.write final + "\n"
  end

  def forward_remote_ports
    @ports.each { |port|
      @logger.debug "Forwarding #{port}"

      forward_msg = Packet.new
      forward_msg.packet_type = PacketType::CONFIGURE_ADD_PORT
      forward_msg.body = port

      send_outbound(forward_msg)
    }
  end

  def handle_packet(packet)
    if packet.packet_type == PacketType::TEST_ENCRYPTION
      if packet.body["test1"] != "encryption_test123"
        raise "Encryption failed. The test encryption packet did not have the constant message"
      else
        @logger.info "Encryption success! The test encryption packet has the constant message."
        @logger.info "Tunnel secure, initializing client"

        # Initialize client
        run_rc
        forward_remote_ports
      end
    elsif packet.packet_type == PacketType::TCP_OPEN
      connection_id = packet.body["connection_id"]
      local_port = packet.body["port"]

      @logger.info "TCP_OPEN on port #{local_port}"

      socket = TCPSocket.new("localhost", local_port)
      @open_clients[connection_id] = socket

      Thread.start do

        while (line = socket.recv(1024))
          new_data = line
          new_data = Base64.encode64(new_data)

          tcp_forward = Packet.new
          tcp_forward.packet_type = PacketType::TCP_FORWARD
          tcp_forward.body = {
            connection_id: connection_id,
            data: new_data
          }

          send_outbound(tcp_forward)
        end

        @logger.debug "TCP_CLOSE on port #{local_port}"
        @open_clients.delete(connection_id)

        tcp_close = Packet.new
        tcp_close.packet_type = PacketType::TCP_CLOSE
        tcp_close.body = {
          connection_id: connection_id,
        }

        send_outbound(tcp_close)
      end

      @logger.debug "New remote to local connection opened with ID #{connection_id} on port #{local_port}"
    elsif packet.packet_type == PacketType::TCP_FORWARD
      connection_id = packet.body["connection_id"]
      data = Base64.decode64(packet.body["data"])

      @open_clients[connection_id].write data
    elsif packet.packet_type == PacketType::TCP_CLOSE
      connection_id = packet.body["connection_id"]

      @open_clients[connection_id].close
      @open_clients.delete(connection_id)

      @logger.debug "TCP_CLOSE on remote connection with ID #{connection_id}"
    end
  end


  def mainloop
    @logger.info "Creating inbound, and outbound encryption modules"
    @inbound_crypto = Crypto.new(false)
    @outbound_crypto = Crypto.new()

    @logger.info "Connecting to remote: #{@address}:#{@port}"

    @remote = TCPSocket.new(@address, @port)

    while (line = @remote.gets("\n"))
      line.strip

      unless @is_encrypted
        @logger.debug "Got welcome packet: #{line}"

        @is_encrypted = true

        next
      end

      # Decrypt, and parse incoming packet
      # Note: Newlines converted to \0 before packet writing

      line.gsub!("\0", "\n")
      decrypted = @inbound_crypto.decrypt(line)
      packet = Packet.new
      packet.from_json(decrypted)

      handle_packet(packet)
    end
  end
end