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
$host =~ /:\d+$/     or $host .= ':10080';

# MAIN
print "Trying host: $host\n";

my $client = new RPC::XML::Client($host);

my @commands = @ARGV;
scalar(@commands) or push @commands, 'retrieve';    # default

print "Sending request: ", join(' ', @commands), "\n";
my $resp = $client->send_request(@commands);

if (ref $resp) {
    print "Return is " . ref($resp), "\n";
    my $code = $resp->{code};
    # print "Code: ", ($resp->{code}->as_string || 'UNKNOWN'), "\n";
    print "Code: ", ($code->value || 'UNKNOWN'), "\n";
}
$verbose and print Dumper($resp);

