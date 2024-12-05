require "logger"
require "socket"
require "./packet.rb"
require "./config.rb"
require "./crypto.rb"
require "./ghost_server.rb"
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
    @outbound_crypto = Crypto.new()

    @ghost_server_list = Hash.new()

    send_packet_noencrypt(welcome)

    test_encryption = Packet.new
    test_encryption.packet_type = PacketType::TEST_ENCRYPTION
    test_encryption.body = {
      test1: "encryption_test123"
    }

    send_packet(test_encryption)
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
      
      @ghost_server_list[packet.body["connection_id"]].send_data(decoded)
    elsif packet.packet_type == PacketType::TCP_CLOSE
      @ghost_server_list[packet.body["connection_id"]].close_connection(true)

      @ghost_server_list.delete(packet.body["connection_id"])

      @logger.warn "Closed connection with ID #{packet.body["connection_id"]}"
    end
  end

  # Handle a new TCP connection to a GhostServer
  def tcp_open(ghost_server, local_port)
    uuid = SecureRandom.uuid

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

class ServerConfig
  attr_accessor :port
  attr_accessor :address

  def initialize
    @port = 9743
    @address = "0.0.0.0"
  end
end

class Server
  attr_accessor :server

  def initialize
    @logger = Logger.new(STDOUT)
    @server_config = ServerConfig.new
  end

  def listen
    @logger.info "Starting blade3 server..."
    @logger.info "Binding to address: #{@server_config.address}:#{@server_config.port}"
  
    EventMachine.run {
      EventMachine.start_server @server_config.address, @server_config.port, Blade3Server
    }
  end
end
