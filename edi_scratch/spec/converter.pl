#!/usr/bin/perl

# This is to turn the UN spec document into perl modules. 
# Crazy, I know.  But would you want to rekey it all?
#
# Spec obtained from:
#   http://www.unece.org/trade/untdid/down_index.htm
#
# Example use:
# 

use strict;
use warnings;

use Business::EDI::Generator qw/ :all /;

our $line;
my %count = ();

sub comment_until {
    my $re = shift;
    $line =~ s/^\s*//;
    print "# ", $line;
    until ($line =~ /$re/) {
        $line = next_line(1);
        $line =~ s/^\s*//;      # kill leading spaces
        print "# ", $line;
    }
}

sub close_file {
    my $file = shift;
    print ");\n";
    print 'sub get_codes { return \%code_hash; }'; 
    print "\n\n1;\n";
    printf STDERR "file: %-53s => %3d %s\n", "$file.pm", ($count{$file} || 0), ($count{$file} ? '' : 'EMPTY!!');
    close STDOUT;
}

my $file;
my $intro = 1;

while ($_ = next_line) {
    if (/-{25}/) {  # Doc separator line
        $intro or close_file($file);
        $intro = 0;
        $line = next_line(1);
        $line =~ /^.\s+(\d{4})\s+(.+)\s\s+\[(.)\]\s*/;
        $file = safename(join '', map {ucfirst} split ' ', ($2 || 'unknown code'));
        open STDOUT, ">$file.pm" or die "Cannot write $file.pm";
        print <<END_OF_PERL;
package Business::EDI::CodeList::$file;

use base 'Business::EDI::CodeList';
my \$VERSION     = 0.01;
my \$list_number = $1;
my \$usage       = '$3';

END_OF_PERL
        comment_until(qr/Repr: /);
        print "\nmy %code_hash = (\n";
        next;
    } elsif ($intro) {
        next;
    } elsif (/^.\s{4}(\S+)\s+(\S.+\S)\s*$/) {
        $count{$file}++;
        printf "%s => [ %s,\n", quotify($1), quotify($2);
        print "    ", quotify(next_chunk), " ],\n";
    }
}

END {
    close_file($file);
    print STDERR scalar(keys %count), " files created\n";
}

__END__
Example UN doc formatting:

     54    Legal statement of an account
              A statement of an account containing the booked items as
              in the ledger of the account servicing financial
              institution.


----------------------------------------------------------------------

*    1001  Document name code                                      [C]

     Desc: Code specifying the document name.

     Repr: an..3

     1     Certificate of analysis
              Certificate providing the values of an analysis.


