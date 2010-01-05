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
$host =~ /:\d+$/     or $host .= ':9090';
$host .= '/RPC2';

# MAIN
print "Trying host: $host\n";

my $client = new RPC::XML::Client($host);

my @commands = @ARGV ? @ARGV : 'system.listMethods';
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
