#!/usr/bin/perl -w
#
# Copyright (C) 2009 Equinox Software, Inc.
# Author: Lebbeous Fogle-Weekley
# Author: Joe Atzberger
#
# License:
#
# This program is free software; you can redistribute it and/or
# modify it under the terms of the GNU General Public License
# as published by the Free Software Foundation; either version 2
# of the License, or (at your option) any later version.
#
# This program is distributed in the hope that it will be useful,
# but WITHOUT ANY WARRANTY; without even the implied warranty of
# MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
# GNU General Public License for more details.
#
# Overview:
#
#   This script is to be used on an asterisk server as an RPC::XML 
#   daemon targeted by Evergreen.
#
# Configuration:
#
#   See the eg-injector.conf and extensions.conf.example files.
#
# Usage:
#
#   perl server.pl -c /path/to/eg-injector.conf
#
# TODO: 
#
# ~ Option to archive (/etc/asterisk/spool/outgoing_really_done) instead of delete?
# ~ Serve retrieval of done files.
# ~ Accept globby prefix for filtering files to be retrieved.
# ~ init.d startup/shutdown/status script.
# ~ More docs.
# ~ perldoc/POD
# - command line usage and --help
#


use RPC::XML::Server;
use Config::General qw/ParseConfig/;
use Getopt::Std;

our (%config, %new_config);
our %opts = (c => "/etc/eg-injector.conf");
our $last_n = 0;

sub load_config {
    %new_config = ParseConfig($opts{c});

    # validate
    foreach my $opt (qw/staging_path spool_path/) {
        if (not -d $new_config{$opt}) {
            warn $new_config{$opt} . " ($opt): no such directory";
            return;
        }
    }

    if ($new_config{port} < 1 || $new_config{port} > 65535) {
        warn $new_config{port} . ": not a valid port number";
        return;
    }

    if (!($new_config{owner} = getpwnam($new_config{owner})) > 0) {
        warn $new_config{owner} . ": invalid owner";
        return;
    }

    if (!($new_config{group} = getgrnam($new_config{group})) > 0) {
        warn $new_config{group} . ": invalid group";
        return;
    }

    %config = %new_config;
}

sub inject {
    my ($data, $timestamp) = @_;
    my $filename_fragment = sprintf("%d-%d.call", time, $last_n++);
    my $filename           = $config{staging_path} . "/" . $filename_fragment;
    my $finalized_filename = $config{spool_path}   . "/" . $filename_fragment;

    my $failure = sub { new RPC::XML::fault(
        faultCode => 500,
        faultString => $_[0]
    )};

    $data .= "; added by inject() in the mediator\n";
    $data .= "Set: callfilename=$filename_fragment\n";

    open FH, ">$filename" or return &$failure("$filename: $!");
    print FH $data or return &$failure("error writing data to $filename: $!");
    close FH or return &$failure("$filename: $!");

    chown($config{owner}, $config{group}, $filename) or
        return &$failure(
            "error changing $filename to $config{owner}:$config{group}: $!"
        );

    if ($timestamp > 0) {
        utime $timestamp, $timestamp, $filename or
            return &$failure("error utime'ing $filename to $timestamp: $!");
    }

    rename $filename, $finalized_filename or
        return &$failure("rename $filename, $finalized_filename: $!");

    return {
        filename => $filename,
        finalized_filename => $finalized_filename,
        code => 200
    };
}

sub main {
    getopt('c:', \%opts);
    load_config;
    $SIG{HUP} = \&load_config;
    my $server = new RPC::XML::Server(port => $config{port});

    $server->add_proc({
        name => 'inject',
        code => \&inject,
        signature => ['struct string int']
    });

    $server->add_default_methods();
    $server->server_loop;
    0;
}

exit main @ARGV;    # do it all!
