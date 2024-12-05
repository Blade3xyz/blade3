#!/usr/bin/env ruby
require_relative "./client.rb"
require_relative "./rc.rb"
require "logger"

logger = Logger.new(STDOUT)
logger.info "Blade3 Client Start"
logger.info "Copyright (c) Hunter Stasonis 2024"

logger.info "--- Running Blade3 RC script... ---"
rc = RunScript.new

logger.info "Ran blade3 rc script"

client = Client.new(rc.address, rc.port)
client.ports = rc.ports
client.mainloop