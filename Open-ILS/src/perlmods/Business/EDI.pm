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

sub codelist {
    my $self = shift;
    Business::EDI::CodeList->new_codelist(@_);
}

sub segment {
    my $self = shift;
#    Business::EDI::Segment->new(@_);
}

sub message {
    my $self = shift;
#    Business::EDI::Message->new(@_);
}

sub dataelement {
    my $self = shift;
#    Business::EDI::DataElement->new(@_);
}

1;
