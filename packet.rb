# frozen_string_literal: true

require_relative "./jsonable.rb"

module PacketType
  UNKNOWN = "unknown"

  # Unencrypted welcome packet, sent when a new client connects to the control server
  WELCOME = "welcome"

  # Add a forwarded port
  CONFIGURE_ADD_PORT = "configure_add_port"

  # Forward a packet from the ghost server
  TCP_FORWARD = "tcp_forward"

  # A new client connected to the ghost server
  TCP_OPEN = "tcp_open"

  # A client disconnected from the ghost server
  TCP_CLOSE = "tcp_close"

  # Test encryption!
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
