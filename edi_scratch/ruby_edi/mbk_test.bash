#!/bin/bash
#
# A wrapper for the ruby-script


function die_msg {
    echo $1;
    exit 1;
}

lib='./acq_edi/lib';
script='./mbk_test.rb';

[ -r "$script" ] || die_msg "Cannot read script at $script";
#[ -d "$lib"    ] || die_msg "Cannot find lib at $lib";
# This doesn't work but RUBYOPT does?
#      export RUBYLIB=$lib

echo export RUBYOPT=rubygems
     export RUBYOPT=rubygems
echo ruby $script
     ruby $script
