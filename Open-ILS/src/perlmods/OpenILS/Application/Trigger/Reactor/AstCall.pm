package OpenILS::Application::Trigger::Reactor::AstCall;
use strict; use warnings;
use Error qw/:try/;
use Data::Dumper;
use OpenSRF::Utils::SettingsClient;
use OpenILS::Application::Trigger::Reactor;
use OpenSRF::Utils::Logger qw/:logger/;
use RPC::XML::Client;
$Data::Dumper::Indent = 0;

use base 'OpenILS::Application::Trigger::Reactor';
use constant DEBUG_FILE => "/tmp/blusah"; #XXX

my $log = 'OpenSRF::Utils::Logger';

sub ABOUT {
    return <<ABOUT;

    The AstCall reactor module creates a callfile for Asterisk, given a
    template describing the message and an environment definining
    necessary information for contacting the Asterisk server and scheduling
    a call with it.

ABOUT
}

#    Channel: SIP/ubab33/$phone_no

sub handler {
    my ($self, $env) = @_;

    $logger->info(__PACKAGE__ . ": entered handler");

    # Here is where we'll later add logic to rotate through
    # multiple available analog channels.
    $env->{channel_prefix} = "SIP/ubab33/";

    my $tmpl_output = $self->run_TT($env);
    if (not $tmpl_output) {
        $logger->error(__PACKAGE__ . ": no template input");
        return 0;
    }

    open (FH, ">>" . DEBUG_FILE) and do {
        print FH "---------------------\n";
        print FH $tmpl_output, "\n";
        print FH "---------------------\n";
        close FH;
    } or do {
        $logger->warn(__PACKAGE__ . ": couldn't write to debug file");
    };

    if (not open FH, ">>" . DEBUG_FILE) { # XXX
        $logger->error(__PACKAGE__ . ": " . DEBUG_FILE . ": $!");
        return 0;
    }

    my $client =  new RPC::XML::Client('http://192.168.71.50:10080/');
    my $resp = $client->send_request('inject', $tmpl_output, 0); # FIXME: 0 could be timestamp if deferred call needed

    print FH ((ref $resp ? ("Response: " . Dumper($resp->value)) : "Error: $resp"), "\n");
    close FH; # XXX

    1;
}

1;

