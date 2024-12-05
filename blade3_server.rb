#!/usr/bin/env ruby
require "./server.rb"
require "./rc.rb"
require "logger"

logger = Logger.new(STDOUT)
logger.info "Blade3 Server Start"
logger.info "Copyright (c) Hunter Stasonis 2024"

logger.info "--- Running Blade3 RC script... ---"
rc = RunScript.new

logger.info "Ran blade3 rc script"

server = Server.new(rc.address, rc.port)
server.listen