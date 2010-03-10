package Business::EDI::CodeList::ServiceRequirementCode;

use base 'Business::EDI::CodeList';
my $VERSION     = 0.01;
my $list_number = 7273;
my $usage       = 'C';

# 7273  Service requirement code                                [C]
# Desc: Code specifying a service requirement.
# Repr: an..3

my %code_hash = (
'1' => [ 'Carrier loads',
    'The cargo is loaded in the equipment by the carrier.' ],
'2' => [ 'Full loads',
    'Container to be stuffed or stripped under responsibility and for account of the shipper or the consignee.' ],
'3' => [ 'Less than full loads',
    'Container to be stuffed and stripped for account and risk of the carrier.' ],
'4' => [ 'Shipper loads',
    'The cargo is loaded in the equipment by the shipper.' ],
'5' => [ 'To be delivered',
    'The cargo is to be delivered as instructed.' ],
'6' => [ 'To be kept',
    'The cargo is to be retained awaiting further instructions.' ],
'7' => [ 'Transhipment allowed',
    'Transhipment of goods is allowed.' ],
'8' => [ 'Transhipment not allowed',
    'Transhipment of goods is not allowed.' ],
'9' => [ 'Partial shipment allowed',
    'Partial shipment is allowed.' ],
'10' => [ 'Partial shipment not allowed',
    'Partial shipment is not allowed.' ],
'11' => [ 'Partial shipment and/or drawing allowed',
    'Partial shipment and/or drawing is allowed.' ],
'12' => [ 'Partial shipment and/or drawing not allowed',
    'Partial shipment and/or drawing is not allowed.' ],
'13' => [ 'Carrier unloads',
    'The cargo is to be unloaded from the equipment by the carrier.' ],
'14' => [ 'Shipper unloads',
    'The cargo is to be unloaded from the equipment by the shipper.' ],
'15' => [ 'Consignee unloads',
    'The cargo is to be unloaded from the equipment by the consignee.' ],
'16' => [ 'Consignee loads',
    'The cargo is to be loaded in the equipment by the consignee.' ],
'17' => [ 'Exclusive usage of equipment',
    'Usage of the equipment is reserved for exclusive use.' ],
'18' => [ 'Non exclusive usage of equipment',
    'Usage of the equipment is not reserved for exclusive use.' ],
'19' => [ 'Direct delivery',
    'Consignment for direct delivery to the consignee.' ],
'20' => [ 'Direct pick-up',
    'Consignment for direct pick-up from the consignee.' ],
'21' => [ 'Request for delivery advice services',
    'The service provider is requested to advise about delivery.' ],
'22' => [ 'Do not arrange customs clearance',
    'Indication that the recipient of the message is not to arrange customs clearance.' ],
'23' => [ 'Arrange customs clearance',
    'Indication that the recipient of the message is to arrange customs clearance.' ],
'24' => [ 'Check container condition',
    'Condition of the container is to be checked.' ],
'25' => [ 'Damaged containers allowed',
    'Damaged containers are allowed.' ],
'26' => [ 'Dirty containers allowed',
    'Dirty containers are allowed.' ],
'27' => [ 'Fork lift holes not required',
    'Container needs not to be equipped with pocket holes, but they are allowed.' ],
'28' => [ 'Fork lift holes required',
    'Container must be equipped with pocket holes.' ],
'29' => [ 'Insure goods during transport',
    'Indication that the recipient of the message is to insure the goods during transport.' ],
'30' => [ 'Arrange main-carriage',
    'Indication that the recipient of the message is to arrange the main-carriage.' ],
'31' => [ 'Arrange on-carriage',
    'Indication that the recipient of the message is to arrange the on-carriage.' ],
'32' => [ 'Arrange pre-carriage',
    'Indication that the recipient of the message is to arrange the pre-carriage.' ],
'33' => [ 'Report container safety convention information',
    'Indication that the information on the Container Safety Convention plate (CSC-plate) should be reported.' ],
'34' => [ 'Check seals',
    'Sealing up of the container is to be checked.' ],
'35' => [ 'Container must be clean',
    'Container is to be released or delivered clean.' ],
'36' => [ 'Request for proof of delivery',
    'The service provider is requested to provide proof of delivery.' ],
'37' => [ 'Request for Customs procedure',
    'The service provider is requested to perform Customs procedure.' ],
'38' => [ 'Request for administration services',
    'The service provider is requested to perform administration services.' ],
'39' => [ 'Transport insulated under Intercontainer INTERFRIGO',
    'conditions Insulated transport under Intercontainer INTERFRIGO (joint European railways agreement) conditions.' ],
'40' => [ 'Transport mechanically refrigerated under Intercontainer',
    'INTERFRIGO conditions Mechanically refrigerated transport under Intercontainer INTERFRIGO (joint European railways agreement) conditions.' ],
'41' => [ 'Cool or freeze service, not under Intercontainer INTERFRIGO',
    'conditions Cool or freeze service not under Intercontainer INTERFRIGO (joint European railways agreement) conditions.' ],
'42' => [ 'Transhipment overseas',
    'Transport equipment is to be transferred overseas.' ],
'43' => [ 'Station delivery',
    'The specified equipment destination station is also the place of delivery of the goods.' ],
'44' => [ 'Non station delivery',
    'The specified equipment destination station is not the place of delivery of the goods.' ],
'45' => [ 'Cleaning or disinfecting',
    'The service required is cleaning or disinfection.' ],
'46' => [ 'Close ventilation valve',
    'The ventilation valve of the equipment must be closed.' ],
'47' => [ 'Consignment held for pick-up',
    'The consignment is to be held until it is picked up.' ],
'48' => [ 'Refrigeration unit check',
    'Refrigeration unit has to be checked.' ],
'49' => [ 'Customs clearance at arrival country by carrier',
    'The carrier is to arrange customs clearance in the arrival country.' ],
'50' => [ 'Customs clearance at departure country by carrier',
    'The carrier is to arrange customs clearance in the departure country.' ],
'51' => [ 'Heating for live animals',
    'Heating for live animals has to be provided.' ],
'52' => [ 'Goods humidification',
    'Humidification of the goods has to be performed.' ],
'53' => [ 'Ensure load is secure',
    'The load must be checked for correct stowage.' ],
'54' => [ 'Open ventilation valve',
    'The ventilation valve of the equipment must be opened.' ],
'55' => [ 'Phytosanitary control',
    'Phytosanitary control to be performed.' ],
'56' => [ 'Tare check by carrier',
    'Carrier must check the tare of the equipment and attached items.' ],
'57' => [ 'Temperature check',
    'The temperature must be checked.' ],
'58' => [ 'Weighing of goods',
    'The goods have to be weighed.' ],
'59' => [ 'Escort',
    'An escort is required.' ],
'60' => [ 'No escort',
    'An escort is not required.' ],
'61' => [ 'Request for berthing services',
    'Request for berthing services at a specific berth in the port area.' ],
'62' => [ 'Request for planned berth consideration',
    'Request to take into account the planned next berth(s) in the port area.' ],
'63' => [ 'Request for inbound passing services through port area',
    'Request for passing services through port area for an inbound voyage (from sea to hinterland) without requesting berth in the port area.' ],
'64' => [ 'Request for outbound passing services through port area',
    'Request for passing services through port area for an outbound voyage (from hinterland to sea) without requesting berth in the port area.' ],
);
sub get_codes { return \%code_hash; }

1;
