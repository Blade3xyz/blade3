# frozen_string_literal: true

class RunScript
  attr_accessor :address
  attr_accessor :port
  attr_accessor :ports

  def initialize(client = true)
    if client
      require "./user/client_config.rb"

      config = ClientConfig.new

      @ports = config.get_ports
      @address = config.get_remote_address
      @port = config.get_remote_port
    else
      require "./user/server_config.rb"

      config = ServerConfig.new

      @address = config.get_address
      @port = config.get_port
    end
  end
end