#!/usr/bin/perl -IOpen-ILS/src/perlmods 

use strict; use warnings;

use Data::Dumper;

use OpenILS::Utils::RemoteAccount;

my $delay = 1;

my %config = (
    remote_host => 'shellz.esilibrary.com',
    remote_user => 'jatzberger',
    remote_password => 'jatzberger',
    remote_file => '/home/jatzberger/out/zzz_testfile',
);

sub content {
    my $time = localtime;
    return <<END_OF_CONTENT;

This is a test file sent at:
$time

END_OF_CONTENT
}

my $x = OpenILS::Utils::RemoteAccount->new(
    remote_host => $config{remote_host},
    remote_user => $config{remote_user},
    content => content(),
);

$Data::Dumper::Indent = 1;
# print Dumper($x);

$delay and print "Sleeping $delay seconds\n" and sleep $delay;

$x->put({
    remote_file => $config{remote_file} . "1.$$",
    content     => content(),
}) or die "ERROR: $x->error";

# print "\n\n", Dumper($x);

my $file  = $x->local_file;
my $rfile = $x->remote_file;
open TEMP, "< $file" or die "Cannot read tempfile $file: $!";
print "\n\ncontent from tempfile $file:\n";
while (my $line = <TEMP>) {
    print $line;
}
close TEMP;

my $dir = '/home/jatzberger/out';
$delay and print "Sleeping $delay seconds\n" and sleep $delay;

my @res1 = $x->ls({remote_file => $dir});
my @res2 = $x->ls($dir);
my @res3 = $x->ls();
my @res4 = $x->ls('.');

my $mismatch = 0;
my $found    = 0;
my $i=0;
print "\n\n";
printf "      %50s | %s\n", "ls ({remote_file => '$dir'})", "ls ('$dir')";
foreach (@res1) {
    my $partner = @res2 ? shift @res2 : '';
    $mismatch++ unless ($_ eq $partner);
    $_ eq $rfile and $found++;
    printf "%4d)%1s%50s %s %s\n", ++$i, ($_ eq $rfile ? '*' : ' '), $_, ($_ eq $partner ? '=' : '!'), $partner;
}

print "\n";
print ($found ? "* The file we just sent" : sprintf("Did not find the file we just sent: \n%58s", $rfile));
print "\nNumber of mismatches: $mismatch\n";
$mismatch and warn "Different style calls to ls got different results.  Please check again.";

$mismatch = $found = $i = 0;
print "\n\n";
printf "      %50s | %s\n", "ls ('.')", "ls ()";
foreach (@res4) {
    my $partner = @res3 ? shift @res3 : '';
    $mismatch++ unless ($_ eq $partner);
    printf "%4d)%1s%50s %s %s\n", ++$i, ($_ eq $rfile ? '*' : ' '), $_, ($_ eq $partner ? '=' : '!'), $partner;
}
print "\n";
print "\nNumber of mismatches: $mismatch\n";
$mismatch and warn "Different style calls to ls got different results.  Please check again.";

print "\n\ndone\n";
exit;

