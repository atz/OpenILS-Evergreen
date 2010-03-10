package Business::EDI::SublineIndicatorCode;

use base 'Business::EDI::CodeList';
my $VERSION     = 0.01;
my $list_number = 5495;
my $usage       = 'B';

# 5495  Sub-line indicator code                                 [B]
# Desc: Code indicating a sub-line item.
# Repr: an..3

my %code_hash = (
'1' => [ 'Sub-line information',
    'Code indicating a sub-line item.' ],
'2' => [ 'Subordinate sub-line information',
    'Indicates that this line item has subordinate sub-lines.' ],
);

1;
