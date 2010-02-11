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

use Data::Dumper;
use vars qw/$debug $x/;

use OpenILS::Utils::Cronscript;
require OpenILS::Utils::CStoreEditor;   # needs to be after bootstrap (in Cronscript)

BEGIN {
    OpenILS::Utils::Cronscript->new({})->session('open-ils.acq') or die "No session created";
}

INIT {
    $debug = 0;
}

use OpenILS::Application::Acq::EDI;

my $res = OpenILS::Application::Acq::EDI->retrieve_core();
print Dumper($res), "\n";
exit;

sub editor {
    my $ed = OpenILS::Utils::CStoreEditor->new(xact => 1) or die "Failed to get new CStoreEditor";
    return $ed;
}

my $i = 5;
my $e = editor;
until (UNIVERSAL::can($e, 'retrieve_all_acq_edi_account') or $i == 0) {
    print STDERR "CStoreEditor FAIL: cannot retrieve_all_acq_edi_account\n";
    delete $INC{'OpenILS/Utils/CStoreEditor.pm'};
    require OpenILS::Utils::CStoreEditor;
    $e = editor;
    print STDERR "EXPECT DEATH: ", $i--, "\n";
    sleep 2;
}

my $set = $e->retrieve_all_acq_edi_account();
print Dumper($set);
# my $res = OpenILS::Application::Acq::EDI->retrieve_core();
# print Dumper($res), "\n";
print "\ndone\n";
