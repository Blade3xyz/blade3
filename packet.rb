# frozen_string_literal: true

require "./jsonable.rb"

module PacketType
  UNKNOWN = "unknown"
  WELCOME = "welcome"
  HANDSHAKE = "handshake"
  CONFIGURE_ADD_PORT = "configure_add_port"
  TCP_FORWARD = "tcp_forward"
  TCP_OPEN = "tcp_open"
  TCP_CLOSE = "tcp_close"
  CLOSE_SERVER = "close_server"
  TEST_ENCRYPTION = "test_encryption"
end

class Packet < JSONable
  attr_accessor :packet_type
  attr_accessor :body

  def initialize
    @packet_type = PacketType::UNKNOWN
    super
  end
end
