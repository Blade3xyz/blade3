# frozen_string_literal: true
require "./server.rb"
require "securerandom"
require "eventmachine"

class GhostServer < EM::Connection
  @client
  def initialize(blade3, remote, local)
    @server = blade3
    @remote_port = remote
    @local_port = local
    @logger = Logger.new(STDOUT)
    @client = nil
  end

  def post_init
    @logger.info "TCP_OPEN on GhostServer running on port #{@remote_port}"
    @server_uuid = @server.tcp_open(self, @local_port)

    @client = self
  end

  def receive_data(data)
    @server.tcp_forward(@server_uuid, data)
  end

  def unbind
    @logger.debug "TCP_CLOSE on GhostServer running on port #{@remote_port}"

    @server.tcp_close(@server_uuid)
  end
end
