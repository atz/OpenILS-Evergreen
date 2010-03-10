#!/usr/bin/perl

# This is to turn the UN spec document into perl modules. 
# Crazy, I know.  But would you want to rekey it all?
#
# Spec obtained from:
#   http://www.unece.org/trade/untdid/down_index.htm
#
# Example use:
#   ./spec/hasher.pl 1 <spec/EDED/EDEDI1.09B >DataElements.pm

use strict;
use warnings;

our $line;
my %count = ();

sub next_line {
    $line = <STDIN>;
    defined($line) or return;
    $line =~ s/\s*$//;      # kill trailing spaces
    $line .= "\n";          # replacing ^M DOS line endings
    if (@_ and $_[0]) {
        next_line() while ($line !~ /\S/);    # skip empties
    }
    return $line;
}

sub quotify {
    my $string = shift or return '';
    $string =~ /'/ or return     "'$string'"    ;   # easiest case, safe for single quotes
    $string =~ /"/ or return '"' . $string . '"';   # contains single quotes, but no doubles.  use doubles
    $string =~ s/'/\\'/g;                           # otherwise it has both, so we'll escape the singles
    return  "'$string'" ;
}

my $intro = 1;
my %types = (   # TODO: maybe preserve some of the bracket data in another hash 
    B => [],
    C => [],
    I => [],
);

while ($_ = next_line) {
    chomp;
    if (/^     Tag   Name/) {  # Doc separator line
        $intro = 0;
        print "\nmy %code_hash = (\n";
        $_ = next_line(1);
    } elsif ($intro) {
        next;
    }
    s/^.\s*//;   # kill leading spaces, and the +, -, X or | that might be there
    $_ or next;
    my ($tag, $name) = split /\s+/, $_, 2;
    $name or die "Could not interpret line $.";
    $name =~ s/\s+\[(.?)\]\s*$//;   # back bracket flag and spaces
    my $type = uc($1 || '');
    printf "$tag => %-65s # %s\n", (quotify($name) . ','), $type;

}
print ");\n";
print "\n1;\n" if @ARGV;

__END__
Example UN doc formatting in EDED/EDEDI1.09B :

     Tag   Name

     1000  Document name                                           [B]
     1001  Document name code                                      [C]
     1003  Message type code                                       [B]
     1004  Document identifier                                     [C]
     1049  Message section code                                    [B]
