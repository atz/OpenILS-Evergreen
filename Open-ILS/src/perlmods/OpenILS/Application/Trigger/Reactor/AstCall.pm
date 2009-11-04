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

sub generate_callfile {
    my ($phone_no, $num_items) = @_;
    my $plurality = ($num_items == 1 ? "singular" : "plural");

    # FIXME: uncoditional prepending of '1' is bad mkay
    return <<END;
Channel: SIP/ubab33/1${phone_no}
Context: overdue-test
MaxRetries: 1
RetryTime: 60
WaitTime: 30
Extension: 10
Archive: 1
Set: items=${num_items}
Set: plurality=${plurality}
END
}

sub handler {
    my ($self, $env) = @_;

    # ??? Where do these config values really come from?  These are not
    # org unit settings... are they?
#    my $conf = OpenSRF::Utils::SettingsClient->new;
#    my $smtp = $conf->config_value('email_notify', 'smtp_server');
#    $$env{default_sender} =
#        $conf->config_value('email_notify', 'sender_address');


    # let's return 0 for failure, 1 for success

    $logger->info(__PACKAGE__ . ": entered handler");
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

    $tmpl_output =~ /phone number:\s*(.+)$/im;
    (my $phone_no = $1) =~ s/[\-\s\(\)]//g;
    $tmpl_output =~ /items:\s*(\d+)/im;
    my $num_items = $1;

    if (not $phone_no or not $num_items) {
        $logger->warn(__PACKAGE__ . ": bad template input; phone_no=$phone_no; num_items=$num_items");
        return 0;
    }

    my $callfile = generate_callfile($phone_no, $num_items);
    if (not open FH, ">>" . DEBUG_FILE) { # XXX
        $logger->error(__PACKAGE__ . ": " . DEBUG_FILE . ": $!");
        return 0;
    }
    print FH $callfile; # XXX

    my $client =  new RPC::XML::Client('http://192.168.71.50:10080/');
    my $resp = $client->send_request('inject', $callfile, 0); # FIXME: 0 could be timestamp if deferred call needed

    print FH ((ref $resp ? ("Response: " . Dumper($resp->value)) : "Error: $resp"), "\n");
    close FH; # XXX

    return 1;
}

1;

