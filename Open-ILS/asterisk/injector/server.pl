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
# ~ Serve retrieval of done files.
# ~ Option to archive (/etc/asterisk/spool/outgoing_really_done) instead of delete?
# ~ Accept globby prefix for filtering files to be retrieved.
# ~ init.d startup/shutdown/status script.
# ~ More docs.
# ~ perldoc/POD
# - command line usage and --help
#

use warnings;
use strict;

use RPC::XML::Server;
use Config::General qw/ParseConfig/;
use Getopt::Std;
use File::Basename qw/basename/;
use Sys::Syslog qw/:standard :macros/;

our %config;
our %opts = (c => "/etc/eg-injector.conf");
our $last_n = 0;

sub load_config {
    %config = ParseConfig($opts{c});

    # validate
    foreach my $opt (qw/staging_path spool_path done_path/) {
        if (not -d $config{$opt}) {
            warn $config{$opt} . " ($opt): no such directory";
            return;
        }
    }

    if ($config{port} < 1 || $config{port} > 65535) {
        warn $config{port} . ": not a valid port number";
        return;
    }

    if ((!($config{owner} = getpwnam($config{owner})) > 0)) {
        warn $config{owner} . ": invalid owner";
        return;
    }

    if ((!($config{group} = getgrnam($config{group})) > 0)) {
        warn $config{group} . ": invalid group";
        return;
    }
}

sub inject {
    my ($data, $timestamp) = @_;
    my $filename_fragment  = sprintf("%d-%d.call", time, $last_n++);
    my $filename           = $config{staging_path} . "/" . $filename_fragment;
    my $finalized_filename = $config{spool_path}   . "/" . $filename_fragment;
    my $failure = sub {
        syslog LOG_ERR, $_[0];

        return new RPC::XML::fault(
            faultCode => 500,
            faultString => $_[0])
    };

    $data .= "; added by inject() in the mediator\n";
    $data .= "Set: callfilename=$filename_fragment\n";

    open FH, ">$filename" or return &$failure("$filename: $!");
    print FH $data or return &$failure("error writing data to $filename: $!");
    close FH or return &$failure("$filename: $!");

    chown($config{owner}, $config{group}, $filename) or
        return &$failure(
            "error changing $filename to $config{owner}:$config{group}: $!"
        );

    if ($timestamp and $timestamp > 0) {
        utime $timestamp, $timestamp, $filename or
            return &$failure("error utime'ing $filename to $timestamp: $!");
    }

    rename $filename, $spooled_filename or
        return &$failure("rename $filename, $spooled_filename: $!");

    syslog LOG_NOTICE, "Spooled $spooled_filename sucessfully";
    return {
        spooled_filename => $spooled_filename,
        code => 200
    };
}

sub retrieve {
    ;
}

sub main {
    getopt('c:', \%opts);
    load_config;
    openlog basename($0), 'ndelay', LOG_USER;
    my $server = new RPC::XML::Server(port => $config{port});

    $server->add_proc({
        name => 'inject', code => \&inject, signature => ['struct string int']
    });

    $server->add_default_methods;
    $server->server_loop;
    0;
}

exit main @ARGV;    # do it all!
