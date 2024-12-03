require "logger"
require "socket"
require "./packet.rb"
require "./config.rb"
require "json"
require "rbnacl"

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
  def initialize
    @logger = Logger.new(STDOUT)
    @server_config = ServerConfig.new
    super
  end

  def handle_client(client)
    # Send welcome message
    welcome = Packet.new
    welcome.packet_type = PacketType::WELCOME
    welcome.body = {
      version: Config::VERSION,
      ruby_version: RUBY_VERSION,
      ruby_copyright: RUBY_COPYRIGHT,
      ruby_platform: RUBY_PLATFORM,
      ruby_description: RUBY_DESCRIPTION
    }

    client.puts welcome.to_json

    @logger.debug "Waiting for incoming packets"

    while (line = client.gets)
      @logger.debug "Received line: #{line}"
    end

    @logger.debug "Client disconnected"
  end

  def listen
    @logger.info "Starting blade3 server..."
    @logger.info "Initializing encryption..."
    @key = RbNaCl::Random.random_bytes(RbNaCl::SecretBox.key_bytes)
    @logger.info "Binding to address: #{@server_config.address}:#{@server_config.port}"
  
    @server = TCPServer.new(@server_config.address, @server_config.port)

    loop do
      Thread.start(@server.accept) do |client|
        @logger.debug "Client connected from #{client.peeraddr}"
        handle_client(client)
      end
    end
  end
end
