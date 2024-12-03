#!/usr/bin/env ruby
require "./client.rb"
require "logger"

logger = Logger.new(STDOUT)
logger.info "Blade3 Client Start"
logger.info "Copyright (c) Hunter Stasonis 2024"

client = Client.new("0.0.0.0", 9743)
client.mainloop