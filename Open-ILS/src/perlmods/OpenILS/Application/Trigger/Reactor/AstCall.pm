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
our $pkg_conf;

sub ABOUT {
    return <<ABOUT;

    The AstCall reactor module creates a callfile for Asterisk, given a
    template describing the message and an environment defining
    necessary information for contacting the Asterisk server and scheduling
    a call with it.

ABOUT
}

sub get_conf {
    $pkg_conf or $pkg_conf = OpenSRF::Utils::SettingsClient->new;   # config object cached by package
    return $pkg_conf;
}

sub get_channels {
    @channels and return @channels;
    # @channels = @{ $conf->config_value('notifications', 'telephony', 'channels') };
    # TODO: real assignment from configs
    return @channels;
}

sub tech_resource_string {
    my $config = get_conf();
    my $tech = $config->config_value('notifications', 'telephony', 'driver') || 'SIP';
    if ($tech !~ /^SIP/) {
        my @chans = get_channels();
        unless(@chans) {
            $logger->error(__PACKAGE__ . ": Cannot build call using $tech, no notifications.telephony.channels found in config!");
            return;
        }
        if (++$last_channel_used > $#chans) {
            $last_channel_used = 0;
        }
        return $chans[$last_channel_used];     # say, 'Zap/1' or 'Zap/12'
    }
    return $tech ;  #  say, 'SIP' or 'SIP/ubab33'
}

sub debug_print {
    if (open (FH, ">>" . DEBUG_FILE)) {
        print FH @_, "\n";
        close FH;
    } else {
        $logger->warn(__PACKAGE__ . ": couldn't write to debug file (" . DEBUG_FILE . "): $!");
    };
}

sub handler {
    my ($self, $env) = @_;
    
    $logger->info(__PACKAGE__ . ": entered handler");

    unless ($env->{channel_prefix} = tech_resource_string()) {      # assignment, not comparison
        $logger->error(__PACKAGE__ . ": Cannot find tech/resource in config");
        return 0;
    }

    my $tmpl_output = $self->run_TT($env);
    if (not $tmpl_output) {
        $logger->error(__PACKAGE__ . ": no template input");
        return 0;
    }

    debug_print(join ("\n", "---------------------", $tmpl_output, "---------------------"));
    my $client = new RPC::XML::Client('http://192.168.71.50:10080/');
    my $resp = $client->send_request('inject', $tmpl_output, 0); # FIXME: 0 could be timestamp if deferred call needed

    debug_print((ref $resp ? ("Response: " . Dumper($resp->value)) : "Error: $resp"));
    1;
}

1;

