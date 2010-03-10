package Business::EDI::InformationCategoryCode;

use base 'Business::EDI::CodeList';
my $VERSION     = 0.01;
my $list_number = 9601;
my $usage       = 'I';

# 9601  Information category code                               [I]
# Desc: Code specifying the category of the information.
# Repr: an..3

my %code_hash = (
'1' => [ 'Timetable',
    'The information is a list of times at which events are scheduled to take place.' ],
'2' => [ 'Price',
    'The information is price related.' ],
'3' => [ 'Location facilities and services',
    'Information about the facilities and services at a location.' ],
'4' => [ 'Travel product and/or service composition',
    'Information about the composition of a travel product and/or service.' ],
'5' => [ 'Miscellaneous',
    'Information concerning miscellaneous categories.' ],
);

1;
