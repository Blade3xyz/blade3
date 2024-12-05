require "logger"
require "socket"
require_relative "./packet.rb"
require_relative "./config.rb"
require_relative "./crypto.rb"
require_relative "./ghost_server.rb"
require "json"
require "eventmachine"

# frozen_string_literal: true

# Actual logic of the server
class Blade3Server < EM::Connection
  include EM::P::LineProtocol

  # Handle new client connection
  def post_init
    @logger = Logger.new(STDOUT)
    @logger.info "New connection to Blade3Server"

    @stats = Hash.new
    @stats["packet_outbound_total"] = 0
    @stats["packet_inbound_total"] = 0
    @stats["packet_outbound_total_size"] = 0
    @stats["packet_inbound_total_size"] = 0

    @stats["connection_inbound_total"] = 0
    @stats["connection_outbound_total"] = 0

    welcome = Packet.new
    welcome.packet_type = PacketType::WELCOME
    welcome.body = {
      Version: Config::VERSION,
      RubyVersion: RUBY_VERSION,
      RubyCopyright: RUBY_COPYRIGHT,
      RubyPlatform: RUBY_PLATFORM,
      RubyDescription: RUBY_DESCRIPTION
    }

    @inbound_crypto = Crypto.new(false)
    @outbound_crypto = Crypto.new

    @ghost_server_list = Hash.new

    send_packet_noencrypt(welcome)

    test_encryption = Packet.new
    test_encryption.packet_type = PacketType::TEST_ENCRYPTION
    test_encryption.body = {
      test1: "encryption_test123"
    }

    send_packet(test_encryption)

    EM.add_periodic_timer(15) do
      puts @stats.to_json
    end
  end

  # Send outbound raw packet. DO NOT SEND INSECURE PAYLOADS WITH THIS
  def send_packet_noencrypt(packet)
    send_data packet.to_json + "\n"
  end

  # Send an outbound encrypted packet
  def send_packet(packet)
    final = @outbound_crypto.encrypt(packet.to_json)
    final.gsub!("\n", "\0")

    send_data final + "\n"

    @stats["packet_outbound_total"] += 1
    @stats["packet_outbound_total_size"] += final.size
  end

  # Forward a local port to remote
  def forward_port(packet)
    client_port = packet.body["client_port"]
    remote_port = packet.body["remote_port"]

    @logger.info "Forwarding port #{client_port} -> #{remote_port}"
    @logger.debug "Starting GhostServer on port #{remote_port}"

    EventMachine.start_server "0.0.0.0", remote_port, GhostServer, self, remote_port, client_port
  end

  # Handle inbound packets
  def handle_packet(packet)
    if packet.packet_type == PacketType::CONFIGURE_ADD_PORT
      forward_port(packet)
    elsif packet.packet_type == PacketType::TCP_FORWARD
      decoded = Base64.decode64(packet.body["data"])

      if @ghost_server_list.has_key?(packet.body["connection_id"])
        @ghost_server_list[packet.body["connection_id"]].send_data(decoded)
      else
        @logger.warn "Ignoring TCP_FORWARD for #{packet.body["connection_id"]}, no such connection with that ID"
      end
    elsif packet.packet_type == PacketType::TCP_CLOSE
      @ghost_server_list[packet.body["connection_id"]].close_connection(true)

      @ghost_server_list.delete(packet.body["connection_id"])

      @logger.warn "Closed connection with ID #{packet.body["connection_id"]}"
    end
  end

  def tcp_close(uuid)
    if @ghost_server_list.has_key?(uuid)
      tcp_close = Packet.new
      tcp_close.packet_type = PacketType::TCP_CLOSE
      tcp_close.body = {
        connection_id: uuid
      }

      @ghost_server_list[uuid].close_connection(true)
      @ghost_server_list.delete(uuid)

      send_packet(tcp_close)
    else
      @logger.error "TCP_CLOSE failed for unknown connection #{uuid}"
    end
  end

  # Handle a new TCP connection to a GhostServer
  def tcp_open(ghost_server, local_port)
    uuid = SecureRandom.uuid

    @stats["connection_outbound_total"] += 1

    @ghost_server_list[uuid] = ghost_server

    tcp_open = Packet.new
    tcp_open.packet_type = PacketType::TCP_OPEN
    tcp_open.body = {
      connection_id: uuid,
      port: local_port
    }

    send_packet(tcp_open)

    @logger.debug "TCP_OPEN with ID #{uuid}"

    uuid
  end

  def tcp_forward(uuid, data)
    @stats["connection_inbound_total"] += 1

    new_data = data
    new_data = Base64.encode64(new_data)

    tcp_forward = Packet.new
    tcp_forward.packet_type = PacketType::TCP_FORWARD
    tcp_forward.body = {
      connection_id: uuid,
      data: new_data
    }

    send_packet(tcp_forward)
  end

  def receive_line(data)
    @stats["packet_inbound_total"] += 1
    @stats["packet_inbound_total_size"] += data.size

    begin
      # Decrypt and parse incoming packets
      decrypted = @inbound_crypto.decrypt(data)
      decrypted.gsub!("\0", "\n")
      packet = Packet.new
      packet.from_json(decrypted)
      
      # Handle packet
      handle_packet(packet)
    rescue => error
      @logger.error "Packet processing failed, packet dropped. #{error.message}"
    end
  end

  def unbind
  end
end

class Server
  attr_accessor :server

  def initialize(address, port)
    @logger = Logger.new(STDOUT)
    @address = address
    @port = port
  end

  def listen
    @logger.info "Starting blade3 server..."
    @logger.info "Binding to address: #{@address}:#{@port}"
  
    EventMachine.run {
      EventMachine.start_server @address, @port, Blade3Server
    }
  end
end
