package Business::EDI::LeafNode;

use strict;
use warnings;
use Carp;
use UNIVERSAL::require;

=head1 Business::EDI::LeafNode

Abstract object class for UN/EDIFACT objects that do not have further descendant objects.

=cut

our $verbose = 0;

sub new_leaf {          # constructor: NOT to be overridden
    my $class = shift;  # note: we don't return objects of this class
    my $type  = shift or carp "No LeafNode object type specified";
    $type or return;
    my $realtype = ($type =~ /^Business::EDI::./) ? $type : "Business::EDI::$type";
    unless ($realtype->require()) {
        carp "require failed! Unrecognized class $realtype: $@";
        return;
    }
    return $realtype->new(@_);
}

sub new {       # constructor: override me if you want
    my $class = shift;
    my $code  = shift or carp "No code argument for LeafNode type '$class' specified";
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
    my $codes = $self->get_codes();
    $codes->{$code} or return;
    $self->{code } = $code;
    $self->{label} = $codes->{$code}->[0];
    $self->{desc}  = $codes->{$code}->[1];
    return $self;
}

sub code  { my $self = shift; @_ and $self->{code } = shift; return $self->{code }; }
sub label { my $self = shift; @_ and $self->{label} = shift; return $self->{label}; }
sub desc  { my $self = shift; @_ and $self->{desc } = shift; return $self->{desc} ; }

1;
