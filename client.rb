# frozen_string_literal: true
require "logger"
require "socket"


class Client
  def initialize(address, port)
    @logger = Logger.new(STDOUT)

    @address = address
    @port = port
  end

  def mainloop
    @logger.info "Connecting to remote: #{@address}:#{@port}"

    @remote = TCPSocket.new(@address, @port)
  end

end