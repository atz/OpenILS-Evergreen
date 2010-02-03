#!/usr/bin/env ruby

# remember to export RUBYLIB=path/to/jedi_stuff

require 'open-uri'
require 'openils/mapper'
require 'edi/edi2json'

puts '../testdata/BakerAndTaylor_Samples/edifact_sample.flat.po'
interchange = open('../testdata/BakerAndTaylor_Samples/edifact_sample.flat.po') { |io| EDI::E::Interchange.parse(io) }
# interchange = open('http://github.com/senator/OpenILS-Evergreen/raw/5815302f00aa0ffed59210a0cfaed2d9927f64c6/edi_scratch/testdata/BakerAndTaylor_Samples/edifact_sample.flat.po') { |io| EDI::E::Interchange.parse(io) }

puts interchange.to_json
puts 'done'
