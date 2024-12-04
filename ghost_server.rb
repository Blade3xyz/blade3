# frozen_string_literal: true
require "./server.rb"
require "securerandom"

class GhostServer
  def initialize(server, address, remote, local)
    @blade3_server  = server
    @logger = Logger.new(STDOUT)

    @server = TCPServer.new(address, remote)
    @local_port = local
    @remote_port = remote
    @connection_id_list = Hash.new
    @can_work = true
  end

  def has_connection_id(test_id)
    @connection_id_list.has_key?(test_id)
  end

  def forward_packet(connection_id, packet)
    if has_connection_id(connection_id)
      begin
        @connection_id_list[connection_id].print(Base64.decode64(packet))
      rescue Errno::EPIPE
        @logger.error "Failed to write to remote connection! Closing connection."
        @connection_id_list.delete(connection_id)
      end
    end
  end

  def handle_client(client)
    @logger.debug "Client connected to remote GhostServer running on port #{@remote_port}"

    connection_id = SecureRandom.uuid

    @connection_id_list[connection_id] = client

    # We got a new connection! Yippee!
    tcp_open = Packet.new
    tcp_open.packet_type = PacketType::TCP_OPEN
    tcp_open.body = {
      port: @local_port,
      connection_id: connection_id,
    }

    @blade3_server.send_outbound_current(tcp_open)

    while (line = client.recv(1024))
      tcp_forward = Packet.new
      tcp_forward.packet_type = PacketType::TCP_FORWARD
      tcp_forward.body = {
        connection_id: connection_id,
        line: Base64.encode64(line)
      }

      @blade3_server.send_outbound_current(tcp_forward)
    end
  end

  def close
    @can_work = false
    @connection_id_list.clear
  end

  def work
    while @can_work do
      Thread.start(@server.accept) do |client|
        @logger.debug "Client connected from #{client.peeraddr}"
        handle_client(client)
      end
    end
  end
end
