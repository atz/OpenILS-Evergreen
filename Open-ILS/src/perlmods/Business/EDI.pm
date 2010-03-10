package Business::EDI;

use strict;
use warnings;
# use Carp;
# use Data::Dumper;

use Business::EDI::CodeList;
# our $verbose = 0;

sub new {
    my($class, %args) = @_;
    my $self = bless(\%args, $class);
    # $self->{args} = {};
    return $self;
}

sub leaf {
    my $self = shift;
    Business::EDI::CodeList->new_leaf(@_);
}

1;
