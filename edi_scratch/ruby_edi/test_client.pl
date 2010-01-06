#!/usr/bin/perl
#

use warnings;
use strict;

use Getopt::Long;
use RPC::XML::Client;
use Data::Dumper;

# DEFAULTS
my $host = 'http://localhost';
my $verbose = 0;

GetOptions(
    'host=s'  => \$host,
    'verbose' => \$verbose,
);

# CLEANUP
$host =~ /^\S+:\/\// or $host  = 'http://' . $host;
$host =~ /:\d+$/     or $host .= ':9191';
$host .= '/EDI';

sub get_in {
    print "Getting JSON from input\n";
    my $json = join("", <STDIN>);
    $json or return;
    print $json, "\n";
    chomp $json;
    return $json;
}

# MAIN
print "Trying host: $host\n";

my $client = new RPC::XML::Client($host);

my @commands = @ARGV ? @ARGV : 'system.listMethods';
if ($commands[0] eq 'json2edi') {
    shift;
    print "Ignoring commands after json2edi\n";
    my $json;
    while ($json = get_in()) {  # assignment
        my $resp = $client->send_request('json2edi', $json);
        print Dumper($resp);
    }
    exit;
} 

print "Sending request: \n    ", join("\n    ", @commands), "\n\n";
my $resp = $client->send_request(@commands);

print Dumper($resp);
exit;

if (ref $resp) {
    print "Return is " . ref($resp), "\n";
    # print "Code: ", ($resp->{code}->as_string || 'UNKNOWN'), "\n";
    foreach (@$resp) {
        print Dumper ($_), "\n";
    }
    foreach (qw(code faultcode)) {
        my $code = $resp->{$_};
        if ($code) {
            print "    ", ucfirst($_), ": ";
            print $code ? $code->value : 'UNKNOWN';
        }
        print "\n";
    }
} else {
    print "ERROR: unrecognized response:\n\n", Dumper($resp), "\n";
}
$verbose and print Dumper($resp);
$verbose and print "\nKEYS (level 1):\n",
    map {sprintf "%12s: %s\n", $_, scalar $resp->{$_}->value} sort keys %$resp;

# print "spooled_filename: ", $resp->{spooled_filename}->value, "\n";
