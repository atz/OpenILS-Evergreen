#!/usr/bin/env ruby

require "xmlrpc/server"

# s = XMLRPC::CGIServer.new()
s = XMLRPC::CGIServer.new(8181)

s.add_handler("sample.sumAndDifference") do |a,b|
    { "sum" => a + b, "difference" => a - b }
end

s.add_introspection
puts "Starting server..." 
s.serve
