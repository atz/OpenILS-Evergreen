#!/usr/bin/perl
#

use warnings;
use strict;

use RPC::XML::Client;
use Data::Dumper;

my $host = @ARGV ? shift : 'http://localhost';
$host =~ /^\S+:\/\// or $host  = 'http://' . $host;
$host =~ /:\d+$/     or $host .= ':10080';
print "Trying host: $host\n";

my $client = new RPC::XML::Client($host);
# TODO: add scheduling intelligence and use it here.

print "Sending 'retrieve' request\n";
my $resp = $client->send_request('retrieve');

if (ref $resp) {
    print "Return is " . ref($resp), "\n";

}
print Dumper($resp);

