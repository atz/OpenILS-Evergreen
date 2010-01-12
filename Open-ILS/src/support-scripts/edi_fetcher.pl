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

use OpenILS::Cronscript;
use Data::Dumper;
my $x = OpenILS::Cronscript->new({foo=>'bar', verbose=>-1, 'my_int=i'=>-1, 'lock-file'=>'/tmp/whatever'});
print "in $0 pt 1: ", Dumper($x);

$x->MyGetOptions({another_opt=>"another_val"});     # adding options at this step not yet implemented
print "in $0 pt 2: ", Dumper($x);

$x->bootstrap;
my $ses = $x->session('open-ils.trigger');
print "SESSION: ", Dumper($ses);
print "done\n";
