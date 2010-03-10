package Business::EDI::GeographicalPositionCodeQualifier;

use base 'Business::EDI::CodeList';
my $VERSION     = 0.01;
my $list_number = 6029;
my $usage       = 'B';

# 6029  Geographical position code qualifier                    [B]
# Desc: Code identifying the type of a geographical position.
# Repr: an..3

my %code_hash = (
'1' => [ 'Start position',
    'A geographical position identifying the start.' ],
'2' => [ 'End position',
    'A geographical position identifying the end.' ],
'3' => [ 'Surface area border point',
    'Point on the border of a surface area.' ],
'4' => [ 'Ship-to-ship activity location',
    'Location of ship-to-ship activity.' ],
);

1;
