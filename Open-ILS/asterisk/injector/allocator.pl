#!/usr/bin/perl -w
#
# Copyright (C) 2009 Equinox Software, Inc.
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
#   This script is designed to run from crontab on a very frequent basis, perhaps
# every minute.  It has two purposes:
#   (1) Prevent the asterisk server from being overwhelmed by a large number of
#       Evergreen callfiles in the queue at once.
#   (2) Allow call window custom scheduling via crontab.  The guarantee is that
#       no more than queue_limit calls will be scheduled at the last
#
#
# Configuration:
#
#   See the eg-injector.conf.
#
# Operation:
#
#   By default no output is produced on successful operation.  Error conditions are
# output, which should result in email to the system user via crontab.
#   Reads the same config file as the mediator, looks at the
# staging directory for any pending callfiles.  If they exist, checks queue_limit
#
# Usage:
#
#   allocator.pl -c /path/to/eg-injector.conf
#
# TODO: 
#
# ~ init.d startup/shutdown/status script.
# ~ More docs.
# ~ perldoc/POD
# - command line usage and --help
#

use warnings;
use strict;

use Config::General qw/ParseConfig/;
use Getopt::Std;
use File::Basename qw/basename fileparse/;
use Sys::Syslog qw/:standard :macros/;
use Cwd qw/getcwd/;

our %config;
our %opts = (
    c => "/etc/eg-injector.conf",
    v => 0
);
our $universal_prefix = 'EG';

sub load_config {
    %config = ParseConfig($opts{c});

    # validate
    foreach my $opt (qw/staging_path spool_path/) {
        if (not -d $config{$opt}) {
            die $config{$opt} . " ($opt): no such directory";
        }
    }

    if (!($config{owner} = getpwnam($config{owner})) > 0) {
        die $config{owner} . ": invalid owner";
    }

    if (!($config{group} = getgrnam($config{group})) > 0) {
        die $config{group} . ": invalid group";
    }

    if ($config{universal_prefix}) {
        $universal_prefix = $config{universal_prefix};
        $universal_prefix =~ /^\D/
            or die "Config error: universal_prefix ($universal_prefix) must start with non-integer character";
    }
}

sub match_files {
# argument: directory to check for files (default cwd)
# returns: array of pathnames from a given dir
    my $root = @_ ? shift : getcwd();
    my $pathglob = "$root/${universal_prefix}*.call";
    my @matches  = grep {-f $_} <${pathglob}>;    # don't use <$pathglob>, that looks like ref to HANDLE
    $opts{v} and print scalar(@matches) . " match(es) for path: $pathglob\n"; 
    syslog LOG_NOTICE, scalar(@matches) . " match(es) for path: $pathglob";
    return @matches;
}

sub prefixer {
    # guarantee universal prefix on string (but don't add it again)
    my $string = @_ ? shift : '';
    $string =~ /^$universal_prefix\_/ and return $string;
    return $universal_prefix . '_' . $string;
}

sub queue {
    my $stage_name = shift or return;
    # chown($config{owner}, $config{group}, $stage_name) or warn "error changing $stage_name to $config{owner}:$config{group}: $!";

    # if ($timestamp and $timestamp > 0) {
    #     utime $timestamp, $timestamp, $stage_name or warn "error utime'ing $stage_name to $timestamp: $!";
    # }
    my $finalized_filename ='';
    my $msg = "$stage_name --> $finalized_filename";
    unless (rename $stage_name, $finalized_filename) {
        print   STDERR  "$msg  FAILED: $!\n";   
        syslog LOG_ERR, "$msg  FAILED: $!";   
        return;
    }

    $opts{v} and print $msg . "\n";
    syslog LOG_NOTICE, $msg;
}

###  MAIN  ###

getopts('vc:', \%opts);
$opts{v} and print "verbose output ON\n";
load_config;    # dies on invalid/incomplete config
openlog basename($0), 'ndelay', LOG_USER;

# incoming files sorted by mtime (stat element 9): OLDEST first
my @incoming = sort {(stat($a))[9] <=> (stat($b))[9]} match_files($config{staging_path});
my @outgoing = match_files($config{spool_path});

my $in_count = scalar @incoming;
my $limit = $config{queue_limit} || 0;
if ($limit and $in_count > $limit) {
    @incoming = @incoming[0..($limit-1)];   # slice down to correct size
}
$opts{v} and print "queue_limit: " . ($limit || 'unlimited') . "\n";
foreach (@incoming) {
    #queue($_);
    print `ls -l $_`, "\n";
}
