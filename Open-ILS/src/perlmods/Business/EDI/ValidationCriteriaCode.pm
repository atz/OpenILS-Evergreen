package Business::EDI::ValidationCriteriaCode;

use base 'Business::EDI::CodeList';
my $VERSION     = 0.01;
my $list_number = 9285;
my $usage       = 'B';

# 9285  Validation criteria code                                [B]
# Desc: Code specifying the validation criteria to be applied.
# Repr: an..3

my %code_hash = (
'1' => [ 'Use any specified value',
    'Any specified value is allowed.' ],
'2' => [ 'Use any code in the standard',
    'Any value from the standard is allowed.' ],
);

1;
