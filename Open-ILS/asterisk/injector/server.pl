#!/usr/bin/perl -w
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

    if ((!($new_config{owner} = getpwnam($new_config{owner})) > 0)) {
        warn $new_config{owner} . ": invalid owner";
        return;
    }

    if ((!($new_config{group} = getpwnam($new_config{group})) > 0)) {
        warn $new_config{group} . ": invalid group";
        return;
    }

    %config = %new_config;
}

sub inject {
    my ($data, $timestamp) = @_;
    my $filename_fragment = sprintf("/%d-%d.call", time, $last_n++);
    my $filename = $config{staging_path} . $filename_fragment;
    my $finalized_filename = $config{spool_path} . $filename_fragment;

    my $failure = sub { new RPC::XML::fault(
        faultCode => 500,
        faultString => $_[0]
    )};

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

exit main @ARGV;
