#!/usr/bin/perl

# This is to turn the UN spec document into perl modules. 
# Crazy, I know.  But would you want to rekey it all?
#
# Spec obtained from:
#   http://www.unece.org/trade/untdid/down_index.htm
#
# Example use:
#   ./spec/hasher.pl 1 <spec/EDED/EDEDI1.09B >DataElement.pm

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
package Business::EDI::DataElement;
use Carp;
use strict;
use warnings;

my %code_hash;

sub new {       # constructor:
    my $class = shift;
    my $code  = shift or carp "No code argument for DataElement type '$class' specified";
    $code or return;
    my $self = bless({}, $class);
    unless ($self->init($code)) {
        carp "init() failed for code '$code'";
        return;
    }
    return $self;
}

sub init {
    my $self = shift;
    my $code = shift or return;
    $code_hash{$code} or return;
    $self->{code } = $code;
    $self->{label} = $code_hash{$code};
    return $self;
}

sub code  { my $self = shift; @_ and $self->{code } = shift; return $self->{code }; }
sub label { my $self = shift; @_ and $self->{label} = shift; return $self->{label}; }
sub desc  {
    my $self = shift;
    local $_ = $self->label();
    my @humps;
    foreach(/([A-Z][a-z]+)/g) {
        push @humps, lc($_);
    }
    return ucfirst join ' ', @humps;
}

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
print "\n1;\n" if @ARGV;

__END__
Example UN doc formatting in EDED/EDEDI1.09B :

     Tag   Name

     1000  Document name                                           [B]
     1001  Document name code                                      [C]
     1003  Message type code                                       [B]
     1004  Document identifier                                     [C]
     1049  Message section code                                    [B]
