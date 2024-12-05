class ServerConfig
  # Get the server's binding address
  def get_address
    return "0.0.0.0"
  end

  # Get the port the server will listen on
  def get_port
    return 9743
  end
end