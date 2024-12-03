#!/usr/bin/env ruby
require "./server.rb"
require "logger"

logger = Logger.new(STDOUT)
logger.info "Blade3 Server Start"
logger.info "Copyright (c) Hunter Stasonis 2024"

server = Server.new
server.listen