package Business::EDI::IndexTypeIdentifier;

use base 'Business::EDI::CodeList';
my $VERSION     = 0.01;
my $list_number = 5027;
my $usage       = 'B';

# 5027  Index type identifier                                   [B]
# Desc: To identify a type of index.
# Repr: an..17

my %code_hash = (
'1' => [ 'Definition',
    'To define the index.' ],
'2' => [ 'Contents',
    'To record the contents of the index.' ],
);

1;
