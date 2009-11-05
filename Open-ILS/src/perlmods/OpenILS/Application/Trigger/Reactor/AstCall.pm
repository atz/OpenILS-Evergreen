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

# $last_channel_used is:
# ~ index (not literal value) of last channel used in a callfile
# ~ index is of position in @channels
# ~ cached at package level
# ~ typically for Zap (PSTN), not VOIP

our @channels;
our $last_channel_used = 0;
our $conf;

sub ABOUT {
    return <<ABOUT;

    The AstCall reactor module creates a callfile for Asterisk, given a
    template describing the message and an environment defining
    necessary information for contacting the Asterisk server and scheduling
    a call with it.

ABOUT
}

sub get_conf {
    $conf or $conf = OpenSRF::Utils::SettingsClient->new;   # conf object cached by package
    return $conf;
}

sub get_channels {
    @channels and return @channels;
    # @channels = @{ $conf->config_value('notifications', 'telephony', 'channels') };
    # TODO: real assignment from configs
    return @channels;
}

sub prepare_channel_line {
    my ($blob) = @_;

    my $phone_no = ($blob =~ /\A; (\d+)$/ms)[0];

    # FIXME: begin North America-centric behavior
    if ($phone_no !~ /^1/) {
        $phone_no = "1" . $phone_no;
    }
    return undef if length $phone_no != 11;
    # FIXME: end North America-centric behavior

    # TODO: Here is where we would introduce logic determining
    # technology, channel or context name, and so on. 
    my $config = get_conf();
    my $tech = $config->config_value('notifications', 'telephony', 'driver') || 'SIP';
    my $techresource;
    if ($tech !~ /^SIP/) {
        my @chans = get_channels();
        unless(@chans) {
            $logger->error(__PACKAGE__ . ":  Cannot call using $tech, no channels listed in config!");
            return;
        }
        if (++$last_channel_used > $#chans) {
            $last_channel_used = 0;
        }
        $techresource = $chans[$last_channel_used];
    } else {
        $techresource = $tech ;  # 'SIP/ubab33'
    }
    return sprintf("Channel: %s/%s\n", $techresource, $phone_no) . $blob;
}

sub handler {
    my ($self, $env) = @_;
    
    $logger->info(__PACKAGE__ . ": entered handler");
#    my $smtp = $conf->config_value('email_notify', 'smtp_server');
#    $$env{default_sender} = $conf->config_value('email_notify', 'sender_address');

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

