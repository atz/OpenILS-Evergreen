package   OpenILS::Application::Trigger::Reactor::SendEmail;
use       OpenILS::Application::Trigger::Reactor;
use base 'OpenILS::Application::Trigger::Reactor';

# use OpenSRF::Utils::SettingsClient;
use OpenSRF::Utils::Logger qw/:logger/;

use Data::Dumper;
use Net::uFTP;
use File::Temp;

$Data::Dumper::Indent = 0;

use strict;
use warnings;

sub ABOUT {
    return <<ABOUT;

The SendFile Reactor Module attempts to transfer a file to a remote host.
Net::uFTP is used, encapsulating the available options of SCP, FTP and SFTP.

No default template is assumed, and all information is expected to be gathered
by the Event Definition through either Environment or Parameter definitions.

Note: none of the remote_X arguments are actually required, except remote_host.
That is because remote_user, remote_password and remote_account can all be 
extrapolated from other sources, as the Net::FTP docs describe:

    If no arguments are given then Net::FTP uses the Net::Netrc package
        to lookup the login information for the connected host.

    If no information is found then a login of anonymous is used.

    If no password is given and the login is anonymous then anonymous@
        will be used for password.

ABOUT
}

sub handler {
    my $self = shift;
    my $env  = shift;

    my $host = $env->{remote_host};
    unless ($host) {
        $logger->error("No remote_host specified in env");
        return;
    }

    my %options = ();
    foreach (qw/debug type port/) {
        $env->{$_} or next;
        $options{$_} = $env->{$_};
    }
    my $ftp = Net::uFTP->new($host, %options);

    # my $conf = OpenSRF::Utils::SettingsClient->new;
    # $$env{something_hardcoded} = $conf->config_value('category', 'whatever');

    my $text = $self->run_TT($env) or return;
    my $tmp  = File::Temp->new();    # magical self-destructing tempfile
    print $tmp $text;
    $logger->info("SendFile Reactor: using tempfile $tmp");

    my @login_args = ();
    foreach (qw/remote_user remote_password remote_account/) {
        push @login_args, $env->{$_} if $env->{$_};
    }
    unless ($ftp->login(@login_args)) {
        $logger->error("SendFile Reactor: failed login to $host w/ args(" . join(',', @login_args) . ")");
        return;
    }

    my @put_args = ($tmp);
    push @put_args, $env->{remote_file} if $env->{remote_file};     # user can specify remote_file name, optionally
    my $filename = $ftp->put(@put_args);
    if ($filename) {
        $logger->info("SendFile Reactor: successfully sent ${host} $filename");
        return 1;
    }

    $text =~ s/\n/ /og;
    $logger->error("SendFile Reactor: failed with error: $! for text $text");
    return;
}

1;

