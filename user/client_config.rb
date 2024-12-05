class ClientConfig
  # Return ports to forward, and their remote mapping
  def get_ports()
    return [
      {
        client_port: 8000,
        remote_port: 8090
      },
      {
        client_port: 25565,
        remote_port: 25568
      }
    ]
  end

  # Get the client remote server address
  def get_remote_address()
    return "0.0.0.0" # CHANGE THIS!!!
  end

  # Get the cleint remote server port
  def get_remote_port()
    return 9743
  end
end
