package Business::EDI::DutyRegimeTypeCode;

use base 'Business::EDI::CodeList';
my $VERSION     = 0.01;
my $list_number = 9213;
my $usage       = 'B';

# 9213  Duty regime type code                                   [B]
# Desc: Code specifying a type of duty regime.
# Repr: an..3

my %code_hash = (
'1' => [ 'Origin subject to EC/EFTA preference',
    'Origin of the product is subject to EC/EFTA (European Commission  European Free Trade Association).' ],
'2' => [ 'Origin subject to other preference agreement',
    'Origin of the product is subject to other preference agreement.' ],
'3' => [ 'No preference origin',
    'Origin of the product is not subject to any preference.' ],
'8' => [ 'Excluded origin',
    'Origin of the product is excluded.' ],
'9' => [ 'Imposed origin',
    'Origin of the product is imposed.' ],
);

1;
