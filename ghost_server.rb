# frozen_string_literal: true
require "./server.rb"
require "securerandom"
require "eventmachine"

class GhostServer < EM::Connection
  def initialize()
    @logger = Logger.new(STDOUT)
  end

  def post_init
    @logger.info "New connection to remote GhostServer running on port #{remote_port}"
  end

  def receive_data(data)
  end

  def unbind
  end
end
