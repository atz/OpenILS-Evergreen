#!/usr/bin/perl

# This is to turn the UN spec document into perl modules. 
# Crazy, I know.  But would you want to rekey it all?
#
# Spec obtained from:
#   http://www.unece.org/trade/untdid/down_index.htm
#
# Example use:
#   ./spec/hasher.pl <spec/EDED/EDEDI1.09B >DataElementList.pm

use strict;
use warnings;

use Business::EDI::Generator qw/ :all /;

our $line;
my %count = ();

my $intro = 1;
my %types = (   # TODO: maybe preserve some of the bracket data in another hash 
    B => [],
    C => [],
    I => [],
);

print <<'END_OF_PERL';
package Business::EDI::DataElementList;
use strict;
use warnings;
use Exporter::Easy (
   OK => [qw( %code_hash list )]
);

my %code_hash;
sub list { return \%code_hash; }

END_OF_PERL

while ($_ = next_line) {
    chomp;
    if (/^     Tag   Name/) {  # Doc separator line
        $intro = 0;
        print "\n%code_hash = (\n";
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
    $name = safename(join '', map {ucfirst} split ' ', ($name || 'unknown code'));
    printf "$tag => %-65s # %s\n", (quotify($name) . ','), $type;

}
print ");\n";
print "\n1;\n";

__END__
Example UN doc formatting in EDED/EDEDI1.09B :

     Tag   Name

     1000  Document name                                           [B]
     1001  Document name code                                      [C]
     1003  Message type code                                       [B]
     1004  Document identifier                                     [C]
     1049  Message section code                                    [B]
