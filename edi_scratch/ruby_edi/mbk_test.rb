#!/usr/bin/env ruby

#    remember to export RUBYLIB=path/to/jedi_stuff
# or remember to export RUBYOPT=rubygems

require 'openils/mapper'
require 'edi/edi2json'

a = ARGV
a.push('../testdata/BakerAndTaylor_Samples/edifact_sample.flat.po') if a.size < 1
a.each { |x|
  interchange = open(x) { |io| EDI::E::Interchange.parse(io) }
  puts x
  puts interchange.to_json
}

puts 'done'
