require "logger"
require "socket"
require "./packet.rb"
require "./config.rb"
require "./crypto.rb"
require "./ghost_server.rb"
require "json"

# frozen_string_literal: true

class ServerConfig
  attr_accessor :port
  attr_accessor :address

  def initialize
    @port = 9743
    @address = "0.0.0.0"
  end
end

class Server
  attr_accessor :ghost_server_list
  attr_accessor :server
  attr_accessor :current_client
  attr_accessor :total_outbound
  attr_accessor :total_inbound
  attr_accessor :total_outbound_packet_size
  attr_accessor :total_inbound_packet_size

  def initialize
    @logger = Logger.new(STDOUT)
    @server_config = ServerConfig.new
    
    @logger.debug "Creating inbound, and outbound Crypto instances..."

    @inbound_crypto = Crypto.new(false)
    @outbound_crypto = Crypto.new(true)

    @ghost_server_list = []
    @current_client = nil

    @total_outbound = 0
    @total_outbound_packet_size = 0

    @total_inbound = 0
    @total_inbound_packet_size = 0
  end

  def send_outbound(client, packet)
    encrypted = @outbound_crypto.encrypt(packet.to_json)

    @total_outbound += 1
    @total_outbound_packet_size += encrypted.size

    client.print encrypted + "\0"
  end

  def send_outbound_current(packet)
    send_outbound(@current_client, packet)
  end

  def map_port(local, remote)
    @logger.info "Starting ghost TCP server for remote port of #{remote}"

    Thread.start do
      server = GhostServer.new(self, "0.0.0.0", remote, local)
      @ghost_server_list.push(server)

      server.work
    end
  end

  def handle_client(client)
    # Send welcome message
    welcome = Packet.new
    welcome.packet_type = PacketType::WELCOME
    welcome.body = {
      Version: Config::VERSION,
      RubyVersion: RUBY_VERSION,
      RubyCopyright: RUBY_COPYRIGHT,
      RubyPlatform: RUBY_PLATFORM,
      RubyDescription: RUBY_DESCRIPTION
    }

    client.print welcome.to_json + "\0"

    test_encryption = Packet.new
    test_encryption.packet_type = PacketType::TEST_ENCRYPTION
    test_encryption.body = {
      test1: "I am a teapot. Encryption works"
    }

    # Send the outbound encryption test packet
    send_outbound(client, test_encryption)

    @logger.debug "Waiting for incoming packets"

    while (line = client.gets "\0")
      # Decrypt the packet
      decrypted = @inbound_crypto.decrypt(line)
      packet = Packet.new
      packet.from_json(decrypted)

      if packet.packet_type == PacketType::CONFIGURE_ADD_PORT
        @logger.debug "Mapping port #{packet.body["client_port"]} -> #{packet.body["remote_port"]}"

        map_port(packet.body["client_port"], packet.body["remote_port"])
      elsif packet.packet_type == PacketType::TCP_FORWARD
        @ghost_server_list.each do |server|
          if server.has_connection_id(packet.body["connection_id"])
            @total_inbound += 1
            @total_inbound_packet_size += line.size

            server.forward_packet(packet.body["connection_id"], packet.body["line"])
          end
        end
      elsif packet.packet_type == PacketType::TCP_CLOSE
        @ghost_server_list.each do |server|
          if server.has_connection_id(packet.body["connection_id"])
            server.close(packet.body["connection_id"])
          end
        end
      end
    end

    @logger.debug "Client disconnected"
  end

  def update_thread
    loop do
      sleep(10)

      @logger.debug "Total outbound packets #{@total_outbound}(#{@total_outbound_packet_size/1000}Kb), total inbound packets #{@total_inbound}(#{@total_inbound_packet_size/1000}Kb)"
    end
  end

  def listen
    @logger.info "Starting blade3 server..."
    @logger.info "Binding to address: #{@server_config.address}:#{@server_config.port}"
  
    @server = TCPServer.new(@server_config.address, @server_config.port)

    Thread.new { update_thread }

    loop do
      Thread.start(@server.accept) do |client|
        @logger.debug "Client connected from #{client.peeraddr}"
        if @current_client != nil
          @logger.warn "Kicking client, I already have a remote server!"
          client.close
        else
          @current_client = client

          handle_client(client)
        end
      end
    end
  end
end
