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
# ~ Server retrieval of done files.
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
use File::Basename qw/basename fileparse/;
use Sys::Syslog qw/:standard :macros/;

our %config;
our %opts = (c => "/etc/eg-injector.conf");
our $last_n = 0;

my $failure = sub {
    syslog LOG_ERR, $_[0];

    return new RPC::XML::fault(
        faultCode => 500,
        faultString => $_[0])
};

my $bad_request = sub {
    syslog LOG_WARNING, $_[0];

    return new RPC::XML::fault(
        faultCode => 400,
        faultString => $_[0])
};

sub load_config {
    %config = ParseConfig($opts{c});

    # validate
    foreach my $opt (qw/staging_path spool_path done_path/) {
        if (not -d $config{$opt}) {
            die $config{$opt} . " ($opt): no such directory";
        }
    }

    if ($config{port} < 1 || $config{port} > 65535) {
        die $config{port} . ": not a valid port number";
    }

    if (!($config{owner} = getpwnam($config{owner})) > 0) {
        die $config{owner} . ": invalid owner";
    }

    if (!($config{group} = getgrnam($config{group})) > 0) {
        die $config{group} . ": invalid group";
    }

    my $path = $config{done_path};
    # warn "done_path '$path'";
    (chdir $path) or die &$failure("Cannot open dir '$path': $!");
}

sub inject {
    my ($data, $timestamp) = @_;
# TODO: add argument for filename_fragment: PREFIX . '_' . userid . '_' . noticetype . '_' . time-serial . '.call'
# TODO: add argument for overwrite based on user + noticetype
    my $filename_fragment  = sprintf("%d-%05d.call", time, $last_n++);
    my $filename           = $config{staging_path} . "/" . $filename_fragment;
    my $finalized_filename = $config{spool_path}   . "/" . $filename_fragment;

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

    rename $filename, $finalized_filename or
        return &$failure("rename $filename, $finalized_filename: $!");

    syslog LOG_NOTICE, "Spooled $finalized_filename sucessfully";
    return {
        spooled_filename => $finalized_filename,
        code => 200
    };
}

sub retrieve {
    my $globstring = @_ ? shift : '*';
    # We depend on being in the correct directory already, thanks to the config step
    # This prevents us from having to chdir for each request.. 
    my @matches = grep {-f $_ } <'./' . $globstring>;    # don't use <$pathglob>, that looks like ref to HANDLE
    my $ret = {
        code => 200,
        glob_used   => $globstring,
        #total_count => scalar(@files),
        match_count => scalar(@matches),
    };
    my $i = 0;
    foreach my $match (@matches) {
        $i++;
        # warn "file $i '$match'";
        unless (open (FILE, "<$match")) {
            syslog LOG_ERR, "Cannot read done file $i of " . scalar(@matches) . ": '$match'";
            $ret->{error_count}++;
            next;
        }
        my @content = <FILE>;   #slurpy
        close FILE;

        $ret->{'file_' . sprintf("%06d",$i++)} = {
            filename => fileparse($match),
            content  => join('', @content),
        };
    }
    return $ret;
}


# cleanup: deletes files
# The list of files to delete must be explicit.  It cannot use globs or any other
# pattern matching because there might be additional files that match.  Asterisk
# might be making calls for other people and prodcesses, or might have made more
# calls for us since the last time we checked.

sub cleanup {
    my $targetstring = shift or return &$bad_request(
        "Must supply at least one filename to cleanup()"     # not empty string!
    );
    my $done = @_ ? shift : 1;  # default is to target done files.
    my @targets = split ',', $targetstring;
    my $path = $done ? $config{done_path} : $config{spool_path};
    (-r $path and -d $path) or return &$failure("Cannot open dir '$path': $!");

    my $ret = {
        code => 200,    # optimism
        request_count => scalar(@targets),
        done          => $done,
        match_count   => 0,
        delete_count  => 0,
    };

    my %problems;
    my $i = 0;
    foreach my $target (@targets) {
        $i++;
        $target =~ s#^(\.\./)##g;    # no fair trying to get us to delete upstream in the filesystem!
        my $file = $path . '/' . $target;
        unless (-f $file) {
            $problems{$target} = {
                code => 404,        # NOT FOUND: may or may not be a true error, since our purpose was to delete it anyway.
                target => $target,
            };
            syslog LOG_NOTICE, "Delete request $i of " . $ret->{request_count} . " for file '$file': File not found";
            next;
        }

        $ret->{match_count}++;
        if (unlink $file) {
            $ret->{delete_count}++;
            syslog LOG_NOTICE, "Delete request $i of " . $ret->{request_count} . " for file '$file' successful";
        } else {
            syslog LOG_ERR,    "Delete request $i of " . $ret->{request_count} . " for file '$file' FAILED: $!";
            $problems{$target} = {
                code => 403,        # FORBIDDEN: permissions problem
                target => $target,
            };
            next;
        }
    }

    my $prob_count = scalar keys %problems;
    if ($prob_count) {
        $ret->{error_count} = $prob_count;
        if ($prob_count == 1 and $ret->{request_count} == 1) {
             # We had exactly 1 error and no successes
            my $one = (values %problems)[0];
            $ret->{code} = $one->{code};     # So our code is the error's code
        } else {
            $ret->{code} = 207;              # otherwise, MULTI-STATUS
            $ret->{multistatus} = \%problems;
        }
    }
    return $ret;
}

sub main {
    getopt('c:', \%opts);
    load_config;    # dies on invalid/incomplete config
    openlog basename($0), 'ndelay', LOG_USER;
    my $server = new RPC::XML::Server(port => $config{port});

    # Regarding signatures:
    #  ~ the first datatype  is  for RETURN value,
    #  ~ any other datatypes are for INCOMING args

    $server->add_proc({
        name => 'inject',   code => \&inject,   signature => ['struct string int']
    });
    $server->add_proc({
        name => 'retrieve', code => \&retrieve, signature => ['struct string', 'struct']
    });
    $server->add_proc({
        name => 'cleanup',  code => \&cleanup,  signature => ['struct string', 'struct string int']
    });

    $server->add_default_methods;
    $server->server_loop;
    0;
}

exit main @ARGV;    # do it all!
