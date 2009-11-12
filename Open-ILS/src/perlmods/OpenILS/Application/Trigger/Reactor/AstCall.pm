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
# ~ index is of position in @channels (zero-based)
# ~ cached at package level
# ~ typically for Zap (PSTN), not VOIP

our @channels;
our $last_channel_used = 0;
our $telephony;

sub ABOUT {
    return <<ABOUT;

    The AstCall reactor module creates a callfile for Asterisk, given a
    template describing the message and an environment defining
    necessary information for contacting the Asterisk server and scheduling
    a call with it.

ABOUT
}

sub get_conf {
    $telephony and return $telephony;
    my $config = OpenSRF::Utils::SettingsClient->new;   
    $telephony = $config->config_value('notifications', 'telephony');  # config object cached by package
    return $telephony;
}

sub get_channels {
    @channels and return @channels;
    my $config = get_conf();    # populated $telephony object
    @channels = @{ $config->{channels} };
    return @channels;
}

sub next_channel {
    # Increments $last_channel_used, or resets it to zero, as necessary.
    # Returns appropriate value from channels array.
    my @chans = get_channels();
    unless(@chans) {
        $logger->error(__PACKAGE__ . ": Cannot build call using " . (shift ||'driver') . ", no notifications.telephony.channels found in config!");
        return;
    }
    if (++$last_channel_used > $#chans) {
        $last_channel_used = 0;
    }
    return $chans[$last_channel_used];     # say, 'Zap/1' or 'Zap/12'
}   

sub channel {
    my $tech = get_conf()->{driver} || 'SIP';
    if ($tech !~ /^SIP/) {
        return next_channel($tech);
    }
    return $tech;                          #  say, 'SIP' or 'SIP/ubab33'
}

sub get_extra_lines {
    my $lines = get_conf()->{callfile_lines} or return '';
    my @fixed;
    foreach (split "\n", $lines) {
        s/^\s*//g;      # strip leading spaces
        /\S/ or next;   # skip empty lines
        push @fixed, $_;
    }
    (scalar @fixed) or return '';
    return join("\n", @fixed) . "\n";
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

    unless ($env->{channel_prefix} = channel()) {      # assignment, not comparison
        $logger->error(__PACKAGE__ . ": Cannot find tech/resource in config");
        return 0;
    }

    $env->{extra_lines} = get_extra_lines() || '';
    my $tmpl_output = $self->run_TT($env);
    if (not $tmpl_output) {
        $logger->error(__PACKAGE__ . ": no template input");
        return 0;
    }

    $logger->info(__PACKAGE__ . ": get_conf()");
    my $conf = get_conf();

    debug_print(join ("\n", "---------------------", $tmpl_output, "---------------------"));

    my $host = $conf->{host};
    unless ($host) {
        $logger->error(__PACKAGE__ . ": No telephony/host in config.");
        return 0;
    }
    $conf->{port} and $host .= ":" . $conf->{port};
    my $client = new RPC::XML::Client($host);
# TODO: add scheduling intelligence and use it here.
    my $resp = $client->send_request('inject', $tmpl_output, 0); # FIXME: 0 could be seconds-from-epoch UTC if deferred call needed

    debug_print((ref $resp ? ("Response: " . Dumper($resp->value)) : "Error: $resp"));
    1;
}

1;

