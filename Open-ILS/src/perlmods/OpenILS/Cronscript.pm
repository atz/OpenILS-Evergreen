package OpenILS::Cronscript;

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

# The purpose of this module is to consolidate the common aspects
# of various cron tasks that all need the same things:
#    ~ non-duplicative processing, i.e. lockfiles and lockfile checking
#    ~ opensrf_core.xml file location 
#    ~ common options like help and debug

use strict;
use warnings;

use Getopt::Long;
use OpenSRF::System;
use OpenSRF::AppSession;
use OpenSRF::Utils::JSON;
use OpenSRF::EX qw(:try);
use OpenILS::Utils::Fieldmapper;
use OpenILS::Lockfile;

use File::Basename qw/fileparse/;

use Data::Dumper;

our @extra_opts = (
    # 'addlopt'
);

our $debug = 0;

sub _default_self {
    return {
    #   opts       => {},
    #   opts_clean => {},
    #   default_opts_clean => {},
        default_opts       => {
            'lock-file=s'   => OpenILS::Lockfile::default_filename,
            'osrf-config=s' => '/openils/conf/opensrf_core.xml',   # TODO: packaging needs a make variable like @@EG_CONF_DIR@@
            'debug'         => 0,
            'verbose+'      => 0,
            'help'          => 0,
            'internal_var'  => 'XYZ',
        },
    #   lockfile => undef,
    }
}

sub is_clean {
    my $key = shift   or  return 1;
    $key =~ /[=:].*$/ and return 0;
    $key =~ /[+!]$/   and return 0;
    return 1;
}

sub clean {
    my $key = shift or return;
    $key =~ s/[=:].*$//;
    $key =~ s/[+!]$//;
    return $key;
}

sub fuzzykey {                      # when you know the hash you want from, but not the exact key
    my $self = shift or return;
    my $key  = shift or return;
    my $target = @_ ? shift : 'opts_clean';
    foreach (map {clean($_)} keys %{$self->{default_opts}}) {  # TODO: cache
        $key eq $_ and return $self->{$target}->{$_};
    }
}

sub MyGetOptions {          # TODO: allow more options to be passed here, maybe mimic Getopt::Long::GetOptions style
    my $self = shift;
    my @keys = sort {is_clean($b) <=> is_clean($a)} keys %{$self->{default_opts}};
    $debug and print "KEYS: ", join(", ", @keys), "\n";
        # {opts} does two things for GetOptions (see Getopt::Long)
        # (1) maps these command-line options to the *other* variables where values are stored (in opts_clean)
        # (2) provides hashspace for the rest of the arbitrary options from the command-line
    foreach (@keys) {
        my $clean = clean($_);
        $self->{opts_clean}->{$clean} = $self->{default_opts_clean}->{$clean};  # prepopulate default
        $self->{opts}->{$_} = \$self->{opts_clean}->{$clean};                   # pointer for GetOptions
    }
    $self->{line_opts} = {};
    GetOptions($self->{opts}, @keys);
    foreach (@keys) {
        delete $self->{opts}->{$_};     # now remove the mappings from (1) so we just have (2)
    }
    $self->clean_mirror('opts');        # populate clean_opts w/ cleaned versions of (2), plus everything else

    print $self->help() and exit if $self->{opts_clean}->{help};
    $debug and $OpenILS::Lockfile::debug = $debug;

    unless ($self->{opts_clean}->{nolockfile} || $self->{default_opts_clean}->{nolockfile}) {
        $self->{lockfile_obj} = OpenILS::Lockfile->new($self->first_defined('lock-file'));
        $self->{lockfile}     = $self->{lockfile_obj}->filename;
    }
}

sub first_defined {
    my $self = shift;
    my $key  = shift or return;
    foreach (qw(opts_clean opts default_opts_clean default_opts)) {
        defined $self->{$_}->{$key} and return $self->{$_}->{$key};
    }
    return;
}

sub clean_mirror {
    my $self  = shift;
    my $dirty = @_ ? shift : 'default_opts';
    foreach (keys %{$self->{$dirty}}) {
        defined $self->{$dirty}->{$_} or next;
        $self->{$dirty . '_clean'}->{clean($_)} = $self->{$dirty}->{$_};
    }
}

sub new {
    my $class = shift;
    my $self  = _default_self;
    bless ($self, $class);
    $self->init(@_);
    $debug and print "new obj: ", Dumper($self);
    return $self;
}

sub add_and_purge {
    my $self = shift;
    my $key  = shift;
    my $val  = shift;
    my $clean = clean($key);
    my @others = grep {/$clean/ and $_ ne $key} keys %{$self->{default_opts}};
    foreach (@others) {
        $debug and print "variant of $key => $_\n";
        if ($key ne $clean) {    # if it is a dirtier key, delete the clean one
            delete $self->{default_opts}->{$_};
            $self->{default_opts}->{$key} = $val;
        } else {                 # else update the dirty one
            $self->{default_opts}->{$_} = $val;
        }
    }
}

sub init {      # not INIT
    my $self = shift;
    my $opts  = @_ ? shift : {};    # user can specify more default options to constructor
# TODO: check $opts is hashref; then check verbose/debug first.  maybe check negations e.g. "no-verbose" ?
    @extra_opts = keys %$opts;
    foreach (@extra_opts) {        # add any other keys w/ default values
        $self->add_and_purge($_, $opts->{$_});
    }
    $self->clean_mirror;
    return $self;
}

sub usage {
    my $self = shift;
    return "\nUSAGE: $0 [OPTIONS]";
}

sub options_help {
    my $self = shift;
    my $chunk = @_ ? shift : '';
    return <<HELP

OPTIONS:
    --osrf-config </path/to/config_file>  Default: $self->{default_opts_clean}->{'osrf-config'}
                 Specify OpenSRF core config file.

    --lock-file </path/to/file_name>      Default: $self->{default_opts_clean}->{'lock-file'}
                 Specify lock file.     

HELP
    . $chunk . <<HELP;
    --debug      Print server responses to STDOUT for debugging
    --verbose    Set verbosity
    --help       Show this help message
HELP
}

sub help {
    my $self = shift;
    return $self->usage() . "\n" . $self->options_help(@_) . $self->example();
}

sub example {
    return "\n\nEXAMPLES:\n\n    $0 --osrf-config /my/other/opensrf_core.xml\n";
}

sub session {
    my $self = shift or return;
    return ($self->{session} ||= OpenSRF::AppSession->create(@_));
}

sub bootstrap {
    my $self = shift or return;
    try {
        $debug and print "bootstrap lock-file  : ", $self->first_defined('lock-file'), "\n";
        $debug and print "bootstrap osrf-config: ", $self->first_defined('osrf-config'), "\n";
        OpenSRF::System->bootstrap_client(config_file => $self->first_defined('osrf-config'));
        Fieldmapper->import(IDL => OpenSRF::Utils::SettingsClient->new->config_value("IDL"));
    } otherwise {
        warn shift;
    };
}

1;
