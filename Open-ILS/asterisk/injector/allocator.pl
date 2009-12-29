#!/usr/bin/perl -w
#
# Copyright (C) 2009 Equinox Software, Inc.
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

=head1 NAME

allocator.pl

=head1 SYNOPSIS

allocator.pl [-h] [-t] [-v] [-c <file>]

 Options:
   -h         display help message
   -t         test mode, no files are moved (impies -v)
   -v         give verbose feedback
   -c <file>  specify config file to be used

=head1 DESCRIPTION

This script is designed to run from crontab on a very frequent basis, perhaps
every minute.  It has two purposes:

=over 8

=item B<1>
Prevent the asterisk server from being overwhelmed by a large number of
Evergreen callfiles in the queue at once.

=item B<2>
Allow call window custom scheduling via crontab.  The guarantee is that
no more than queue_limit calls will be scheduled at the last scheduled run.

=back

By default no output is produced on successful operation.  Error conditions are
output, which should result in email to the system user via crontab.
Reads the same config file as the mediator, looks at the
staging directory for any pending callfiles.  If they exist, checks queue_limit

=head1 CONFIGURATION

See the eg-injector.conf.  In particular, set use_allocator to 1 to indicate to
both processes (this one and the mediator) that the allocator is scheduled to run.

=head1 USAGE EXAMPLES

allocator.pl

allocator.pl -c /path/to/eg-injector.conf

allocator.pl -t -c /some/other/config.txt

=head1 TODO

=over 8

=item LOAD TEST!!

=back

=head1 AUTHOR

Joe Atzberger,
Equinox Software, Inc.

=cut 

use warnings;
use strict;

use Config::General qw/ParseConfig/;
use Getopt::Std;
use Pod::Usage;
use File::Basename qw/basename fileparse/;
use File::Spec;
use Sys::Syslog qw/:standard :macros/;
use Cwd qw/getcwd/;

our %config;
our %opts = (
    c => "/etc/eg-injector.conf",
    v => 0,
    t => 0,
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
    unless ($config{use_allocator} or $opts{t}) {
        die "use_allocator not enabled in config file (mediator thinks allocator is not in use).  " .
            "Run in test mode (-t) or enable use_allocator config";
    }
}

sub match_files {
# argument: directory to check for files (default cwd)
# returns: array of pathnames from a given dir
    my $root = @_ ? shift : getcwd();
    my $pathglob = "$root/${universal_prefix}*.call";
    my @matches  = grep {-f $_} <${pathglob}>;    # don't use <$pathglob>, that looks like ref to HANDLE
    $opts{v} and             print scalar(@matches) . " match(es) for path: $pathglob\n"; 
    $opts{t} or syslog LOG_NOTICE, scalar(@matches) . " match(es) for path: $pathglob";
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
    $opts{t} or chown($config{owner}, $config{group}, $stage_name) or warn "error changing $stage_name to $config{owner}:$config{group}: $!";

    # if ($timestamp and $timestamp > 0) {
    #     utime $timestamp, $timestamp, $stage_name or warn "error utime'ing $stage_name to $timestamp: $!";
    # }
    my $goodname = prefixer((fileparse($stage_name))[0]);
    my $finalized_filename = File::Spec->catfile($config{spool_path}, $goodname);
    my $msg = sprintf "%40s --> %s", $stage_name, $finalized_filename;
    unless ($opts{t}) {
        unless (rename $stage_name, $finalized_filename) {
            print   STDERR  "$msg  FAILED: $!\n";   
            syslog LOG_ERR, "$msg  FAILED: $!";   
            return;
        }
        syslog LOG_NOTICE, $msg;
    }
    $opts{v} and print $msg . "\n";
}

###  MAIN  ###

getopts('htvc:', \%opts) or pod2usage(2);
pod2usage( -verbose => 2 ) if $opts{h};

$opts{t} and $opts{v} = 1;
$opts{t} and print "TEST MODE\n";
$opts{v} and print "verbose output ON\n";
load_config;    # dies on invalid/incomplete config
openlog basename($0), 'ndelay', LOG_USER;

my $now = time;
# incoming files sorted by mtime (stat element 9): OLDEST first
my @incoming = sort {(stat($a))[9] <=> (stat($b))[9]} match_files($config{staging_path});
my @outgoing = match_files($config{spool_path});
my @future   = ();

my $raw_count = scalar @incoming;
for (my $i=0; $i<$raw_count; $i++) {
    if ((stat($incoming[$i]))[9] - $now > 0 ) { # if this file is from the future, then so are the subsequent ones
        @future = splice(@incoming,$i);         # i.e., take advantage of having sorted them already
        last;
    }
}

# note: elements of @future not currently used beyond counting them

my  $in_count = scalar @incoming;
my $out_count = scalar @outgoing;
my $limit     = $config{queue_limit} || 0;
my $available = 0;

if ($limit) {
    $available = $limit - $out_count;
    if ($in_count > $available) {
        @incoming = @incoming[0..($available-1)];   # slice down to correct size
    }
    if ($available == 0) {
        $opts{t} or syslog LOG_NOTICE, "Queue is full ($limit)";
    }    
}

if ($opts{v}) {
     printf "incoming (total ): %3d\n", $raw_count;
     printf "incoming (future): %3d\n", scalar @future;
     printf "incoming (active): %3d\n", $in_count;
     printf "queued already   : %3d\n", $out_count;
     printf "queue_limit      : %3d\n", $limit;
     printf "available spots  : %3s\n", ($limit ? $available : 'unlimited');
}

foreach (@incoming) {
    # $opts{v} and print `ls -l $_`;  # '  ', (stat($_))[9], " - $now = ", (stat($_))[9] - $now, "\n";
    queue($_);
}

