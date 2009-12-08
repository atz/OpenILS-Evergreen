package OpenILS::Application::Trigger::Reactor::AstCall;
use base 'OpenILS::Application::Trigger::Reactor';
# unneeded: use OpenILS::Application::Trigger::Reactor;
# AND the base already does:
use OpenSRF::Utils::Logger qw($logger);
# use OpenILS::Application::AppUtils;
# use OpenILS::Utils::CStoreEditor qw/:funcs/;
# etc.

use strict; use warnings;
use Error qw/:try/;
use Data::Dumper;

use OpenSRF::Utils::SettingsClient;
use RPC::XML::Client;
$Data::Dumper::Indent = 0;

my $U = 'OpenILS::Application::AppUtils';

use constant DEBUG_FILE => "/tmp/blusah"; #XXX

my $e = new_editor(xact => 1);

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

    my @eventids = map {$_->id} @{$env->{event}};
    @eventids or push @eventids, '';

    my $eo = Fieldmapper::action_trigger::event_output->new;
    $tmpl_output .= "; Added by __PACKAGE__ handler:\n";
    $tmpl_output .= $env->{extra_lines} if $env->{extra_lines};
    $tmpl_output .= "; event_ids = " . join(",",@eventids) . "\n";    # or would we prefer distinct lines instead of comma-seoarated?
    $tmpl_output .= "; event_output = " . $eo->id . "\n";

    debug_print(join ("\n", "------ template output -----", $tmpl_output, "---------------------"));
    debug_print(join ("\n", "------ env dump ------------", Dumper($env), "---------------------"));

    my $host = $conf->{host};
    unless ($host) {
        $logger->error(__PACKAGE__ . ": No telephony/host in config.");
        return 0;
    }
    $host =~ /^\S+:\/\// or $host  = 'http://' . $host;     # prepend http:// if no protocol specified
    $conf->{port} and $host .= ":" . $conf->{port};         # append port number if specified

    my $client = new RPC::XML::Client($host);
    #my $filename_fragment = $userid . '_' . $eventids[0] . 'uniq' . time; # not $noticetype,
    my $filename_fragment = $eo->id . '_' . $eo->id;    # the event_output.id tells us all we need to know

    # TODO: add scheduling intelligence and use it here... or not if relying only on crontab
    my $resp = $client->send_request('inject', $tmpl_output, $filename_fragment, 0); # FIXME: 0 could be seconds-from-epoch UTC if deferred call needed

    debug_print(ref $resp ? ("Response: " . Dumper($resp->value)) : "Error: $resp");

    if ($resp->{code} and $resp->{code}->value == 200) {
        $eo->is_error('f');
        $eo->data('filename: ' . $resp->{spooled_filename}->value);
        # could look for the file that replaced it
    } else {
        $eo->is_error('t');
        my $msg = ($resp->{faultcode}) ? $resp->{faultcode}->value : " -- UNKNOWN response '$resp'";
        $msg .= " for $filename_fragment";
        $eo->data("Error " . $msg);
        $logger->error(__PACKAGE__ . ": Mediator Error " . $msg);
    }

    # Now point all our events' async_output to the newly made row
    $eo = $env->{EventProcessor}->editor->create_action_trigger_event_output( $eo );
    foreach (@eventids) {
        my $event = $e->retrieve_action_trigger_event($_);
        $event->async_output($eo->id);
        $e->commit;
    }

    # TODO: a sub for saving async_output might belong in Trigger.pm
    1;
}

1;

