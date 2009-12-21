#!/usr/bin/perl

use strict;
use warnings;

use Net::uFTP;
use Net::SSH2;
use Data::Dumper;

my $host = 'shellz.esilibrary.com';
my $user = 'jatzberger';

my $ssh2 = Net::SSH2->new();
$ssh2->connect($host) or print "SSH2 connect FAILED: $!" . join("\n",$ssh2->error);
print "Connected w/ Net::SSH2->new->connect\n";
print "\tssh object: ", Dumper($ssh2), "\n";
print "Auth types supported (for $user): ", join(", ", $ssh2->auth_list($user)), "\n";

$ssh2->auth(
    username   => $user,
    rank => [qw/ publickey hostbased password /],
    publickey  => '/home/opensrf/.ssh/id_rsa.pub',
    privatekey => '/home/opensrf/.ssh/id_rsa',
    interactive=> 0,
) or die "ssh2->auth FAILED: $!";

=doc

$ssh2->auth_publickey(
    'jatzberger',
    '/home/opensrf/.ssh/id_rsa.pub',
    '/home/opensrf/.ssh/id_rsa',
) or die "auth_publickey FAILED: $!";

=cut

my $ftp = $ssh2->sftp() or die "ssh2->sftp FAILED: $!";
print "ssh->stfp object:", Dumper($ftp), "\n/home :\n";
my $dh = $ftp->opendir('/home');
while(my $item = $dh->read) {
    print $item->{'name'},"\n";
}

$dh = $ftp->opendir("/home/$user");
print "\n\n/home/$user : \n";
while(my $item = $dh->read) {
    print $item->{'name'},"\n";
}

my $res = $ssh2->scp_put($0,"/home/$user/ftptest.txt");

print "\nres = $res\ndone\n";
__END__

# print "simple ls: ", join("\n\t", keys %$dh), "\n";

foreach (qw(SFTP SCP FTP)) {
    printf "\n%4s Attempting w/ uFTP\n", $_ ;
    my $ftp = Net::uFTP->new('shellz.esilibrary.com', type => $_, debug => 1);
    unless($ftp->login()) {
        printf STDERR "%4s Failed login\n", $_ ;
        next;
    }
    print $ftp->ls(), "\n";
}

