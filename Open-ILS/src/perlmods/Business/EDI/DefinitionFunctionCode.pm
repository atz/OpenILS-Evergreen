package Business::EDI::DefinitionFunctionCode;

use base 'Business::EDI::CodeList';
my $VERSION     = 0.01;
my $list_number = 9023;
my $usage       = 'B';

# 9023  Definition function code                                [B]
# Desc: Code specifying the function of a definition.
# Repr: an..3

my %code_hash = (
'1' => [ 'Alias',
    'To specify an alias function.' ],
'2' => [ 'Constraint',
    'To specify a constraint function.' ],
'3' => [ 'Implementation',
    'To specify an implementation function.' ],
);

1;
