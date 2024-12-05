# frozen_string_literal: true

class RunScript
  attr_accessor :address
  attr_accessor :port
  attr_accessor :ports

  def initialize(client = true)
    if client
      if File.exist? "./user/client_config.rb"
        require "./user/client_config.rb"
      else
        require "/var/blade3/client_config.rb"
      end

      config = ClientConfig.new

      @ports = config.get_ports
      @address = config.get_remote_address
      @port = config.get_remote_port
    else
      if File.exist? "./user/server_config.rb"
        require "./user/server_config.rb"
      else
        require "/var/blade3/server_config.rb"
      end

      config = ServerConfig.new

      @address = config.get_address
      @port = config.get_port
    end
  end
end