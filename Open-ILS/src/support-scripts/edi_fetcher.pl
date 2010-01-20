#!/usr/bin/perl
# ---------------------------------------------------------------
# Copyright (C) 2010 Equinox Software, Inc
# Author: Joe Atzberger <jatzberger@esilibrary.com>
#
# This program is free software; you can redistribute it and/or
# modify it under the terms of the GNU General Public License
# as published by the Free Software Foundation; either version 2
# of the License, or (at your option) any later version.

# This program is distributed in the hope that it will be useful,
# but WITHOUT ANY WARRANTY; without even the implied warranty of
# MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
# GNU General Public License for more details.
# ---------------------------------------------------------------

use strict;
use warnings;

use OpenILS::Utils::Cronscript;
use Data::Dumper;

use vars qw/$debug/;

INIT { $debug = 1; }

my $x = OpenILS::Utils::Cronscript->new({foo=>'bar', verbose=>-1, 'my_int=i'=>-1, 'lock-file'=>'/tmp/whatever'});
$debug and print "in $0 pt 1: ", Dumper($x);

$x->MyGetOptions({another_opt=>"another_val"});     # adding options at this step not yet implemented
$debug and print "in $0 pt 2: ", Dumper($x);

$x->bootstrap;
my $ses = $x->session('open-ils.acq');
$debug and print "SESSION: ", Dumper($ses);

my $req = $ses->request('open-ils.acq.edi_account.retrieve');
while (my $resp = $req->recv(timeout => 1800)) {
    $resp;
    # parse
    # extract event ID
    # add to async_data
    # update status
}


$debug and print "done\n";
