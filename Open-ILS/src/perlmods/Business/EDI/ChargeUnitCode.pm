package Business::EDI::ChargeUnitCode;

use base 'Business::EDI::CodeList';
my $VERSION     = 0.01;
my $list_number = 5261;
my $usage       = 'I';

# 5261  Charge unit code                                        [I]
# Desc: Code specifying a charge unit.
# Repr: an..3

my %code_hash = (
'1' => [ 'Drop charge',
    'Fee charged when a rental is terminated in a city or location other than where the rental originated.' ],
'2' => [ 'Extra day',
    'The associated charge is for each day beyond the indicated base period.' ],
'3' => [ 'Extra week',
    'The associated charge is for each week beyond the indicated base period.' ],
'4' => [ 'Extra hour',
    'The associated charge is for each hour beyond the indicated base period.' ],
'5' => [ 'Extra month',
    'The associated charge is for each month beyond the indicated base period.' ],
'6' => [ 'Per mile',
    'The associated charge is for each mile the service is in use.' ],
'7' => [ 'Per kilometer',
    'The associated charge is for each kilometer the service is in use.' ],
'8' => [ 'Free miles',
    'To indicate there is no charge for the specified number of free miles.' ],
'9' => [ 'Free kilometers',
    'To indicate there is no charge for the specified number of free kilometers.' ],
'10' => [ 'Adult',
    'The associated charge is per adult.' ],
'11' => [ 'Child',
    'The associated charge is per child.' ],
'12' => [ 'Employee',
    'The associated charge is per employee.' ],
'13' => [ 'Passenger in wheelchair',
    'The associated tariff is to accommodate a passenger in a wheelchair.' ],
'14' => [ 'Companion of a handicapped person',
    'The associated tariff is per companion of a handicapped person such as a blind passenger or a passenger in a wheelchair.' ],
'15' => [ 'Small contained animal',
    'The associated tariff is per animal up to the size of a domestic cat, stalled in suitable containers such as a cage, box or basket.' ],
'16' => [ 'Dog',
    'The associated tariff is per dog.' ],
'17' => [ 'Bicycle',
    'The associated tariff is per bicycle.' ],
'18' => [ 'Youth',
    'The associated tariff is for a person between childhood and adult age.' ],
'19' => [ 'Senior',
    'The associated tariff is for an elderly person such as an old age pensioner.' ],
'20' => [ 'Infant',
    'The associated tariff is per very young child or baby.' ],
'21' => [ 'Accompanied child',
    'The associated tariff is per child accompanied by an adult.' ],
'22' => [ 'Child as separate passenger',
    'The associated tariff is per child occuping their own seat, couchette or sleeping berth.' ],
'23' => [ 'Blind person',
    'The associated tariff is per blind person.' ],
'24' => [ 'Infant as separate passenger',
    'The associated tariff is per infant occupying their own seat, couchette or sleeping berth.' ],
'25' => [ 'Person aged between 4 and 11 years',
    'The associated charge is per person between 4 and 11 years.' ],
'26' => [ 'Child accompanied by ancestor',
    'The associated charge is per child accompanied by an ancestor.' ],
'27' => [ 'Person aged between 4 and 12 years',
    'The associated charge is per person between 4 and 12 years.' ],
'28' => [ 'Person aged between 4 and 13 years',
    'The associated charge is per person between 4 and 13 years.' ],
'29' => [ 'Person aged between 4 and 16 years',
    'The associated charge is per person between 4 and 16 years.' ],
'30' => [ 'Person aged between 5 and 12 years',
    'The associated charge is per person between 5 and 12 years.' ],
'31' => [ 'Person aged between 5 and 16 years',
    'The associated charge is per person between 5 and 16 years.' ],
'32' => [ 'Person aged between 6 and 12 years',
    'The associated charge is per person between 6 and 12 years.' ],
'33' => [ 'Person aged between 6 and 14 years',
    'The associated charge is per person between 6 and 14 years.' ],
'34' => [ 'Person aged between 6 and 15 years',
    'The associated charge is per person between 6 and 15 years.' ],
'35' => [ 'Person aged between 6 and 16 years',
    'The associated charge is per person between 6 and 16 years.' ],
'36' => [ 'Person aged between 6 and 17 years',
    'The associated charge is per person between 6 and 17 years.' ],
'37' => [ 'Person aged between 7 and 12 years',
    'The associated charge is per person between 7 and 12 years.' ],
'38' => [ 'Person aged between 7 and 15 years',
    'The associated charge is per person between 7 and 15 years.' ],
'39' => [ 'Person aged between 11 and 99 years',
    'The associated charge is per person between 11 and 99 years.' ],
'40' => [ 'Person aged between 12 and 99 years',
    'The associated charge is per person between 12 and 99 years.' ],
'41' => [ 'Person aged between 13 and 99 years',
    'The associated charge is per person between 13 and 99 years.' ],
'42' => [ 'Person aged between 14 and 99 years',
    'The associated charge is per person between 14 and 99 years.' ],
'43' => [ 'Person aged between 15 and 99 years',
    'The associated charge is per person between 15 and 99 years.' ],
'44' => [ 'Person aged between 16 and 99 years',
    'The associated charge is per person between 16 and 99 years.' ],
'45' => [ 'Person aged between 17 and 99 years',
    'The associated charge is per person between 17 and 99 years.' ],
'46' => [ 'Person aged between 26 and 99 years',
    'The associated charge is per person between 26 and 99 years.' ],
);

1;
