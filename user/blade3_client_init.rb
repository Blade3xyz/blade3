class UserConfigInit
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
end
