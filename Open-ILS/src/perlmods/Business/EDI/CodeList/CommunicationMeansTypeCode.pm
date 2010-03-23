package Business::EDI::CodeList::CommunicationMeansTypeCode;

use base 'Business::EDI::CodeList';
my $VERSION     = 0.01;
my $list_number = 3155;
my $usage       = 'B';

# 3155  Communication means type code                           [B]
# Desc: Code specifying the type of communication address.
# Repr: an..3

my %code_hash = (
'AA' => [ 'Circuit switching',
    'A process that, on demand, connects two or more data terminal equipments and permits the exclusive use of a data circuit between them until the connection is released (ISO).' ],
'AB' => [ 'SITA',
    'Communications number assigned by Societe Internationale de Telecommunications Aeronautiques (SITA).' ],
'AC' => [ 'ARINC',
    'Communications number assigned by Aeronautical Radio Inc.' ],
'AD' => [ 'AT&T mailbox',
    'AT&T mailbox identifier.' ],
'AE' => [ 'Peripheral device',
    'Peripheral device identification.' ],
'AF' => [ 'U.S. Defense Switched Network',
    'The switched telecommunications network of the United States Department of Defense.' ],
'AG' => [ 'U.S. federal telecommunications system',
    'The switched telecommunications network of the United States government.' ],
'AH' => [ 'World Wide Web',
    'Data exchange via the World Wide Web.' ],
'AI' => [ 'International calling country code',
    'Identifies that portion of an international telephone number representing the country code to be used when calling internationally.' ],
'AJ' => [ 'Alternate telephone',
    'Identifies the alternate telephone number.' ],
'AK' => [ 'Videotex number',
    'Code that identifies the communications number for the online videotex service.' ],
'AL' => [ 'Cellular phone',
    'Identifies the cellular phone number.' ],
'AM' => [ 'International telephone direct line',
    'The international telephone direct line number.' ],
'AN' => [ 'O.F.T.P. (ODETTE File Transfer Protocol)',
    'ODETTE File Transfer Protocol.' ],
'AO' => [ 'Uniform Resource Location (URL)',
    'Identification of the Uniform Resource Location (URL) Synonym: World wide web address.' ],
'AP' => [ 'Very High Frequency (VHF) radio telephone',
    'VHF radio telephone.' ],
'AQ' => [ 'X.400 address for mail text',
    'The X.400 address accepting information in the body text of a message.' ],
'AR' => [ 'AS1 address',
    'Address capable of receiving messages in accordance with the EDIINT/AS1 protocol for MIME based EDI .' ],
'AS' => [ 'AS2 address',
    'Address capable of receiving messages in accordance with the EDIINT/AS2 protocol.' ],
'AT' => [ 'AS3 address',
    'Address capable of receiving messages in accordance with the EDIINT/AS3 protocol.' ],
'AU' => [ 'File Transfer Protocol',
    'Address capable for receiving message in accordance with the File Transfer Protocol (IETF RFC 959 et. al.).' ],
'AV' => [ 'Inmarsat call number',
    'Contact number based on Inmarsat.' ],
'CA' => [ 'Cable address',
    'The communication number identifies a cable address.' ],
'EI' => [ 'EDI transmission',
    'Number identifying the service and service user.' ],
'EM' => [ 'Electronic mail',
    'Exchange of mail by electronic means.' ],
'EX' => [ 'Extension',
    'Telephone extension.' ],
'FT' => [ 'File transfer access method',
    'According to ISO.' ],
'FX' => [ 'Telefax',
    'Device used for transmitting and reproducing fixed graphic material (as printing) by means of signals over telephone lines or other electronic transmission media.' ],
'GM' => [ 'GEIS (General Electric Information Service) mailbox',
    'The communication number identifies a GEIS mailbox.' ],
'IE' => [ 'IBM information exchange',
    'The communication number identifies an IBM IE mailbox.' ],
'IM' => [ 'Internal mail',
    'Internal mail address/number.' ],
'MA' => [ 'Mail',
    'Postal service document delivery.' ],
'PB' => [ 'Postbox number',
    'The communication number identifies a postbox.' ],
'PS' => [ 'Packet switching',
    'The process of routing and transferring data by means of addressed packets so that a channel is occupied only during the transmission; upon completion of the transmission the channel is made available for the transfer of other packets (ISO).' ],
'SW' => [ 'S.W.I.F.T.',
    'Communications address assigned by Society for Worldwide Interbank Financial Telecommunications s.c.' ],
'TE' => [ 'Telephone',
    'Voice/data transmission by telephone.' ],
'TG' => [ 'Telegraph',
    'Text transmission via telegraph.' ],
'TL' => [ 'Telex',
    'Transmission of text/data via telex.' ],
'TM' => [ 'Telemail',
    'Transmission of text/data via telemail.' ],
'TT' => [ 'Teletext',
    'Transmission of text/data via teletext.' ],
'TX' => [ 'TWX',
    'Communication service involving Teletypewriter machines connected by wire or electronic transmission media. Teletypewriter machines are the devices used to send and receive signals and produce hardcopy from them.' ],
'XF' => [ 'X.400 address',
    'The X.400 address.' ],
'XG' => [ 'Pager',
    'Identifies that the communication number is for a pager.' ],
'XH' => [ 'International telephone switchboard',
    'The international telephone switchboard number.' ],
'XI' => [ 'National telephone direct line',
    'The national telephone direct line number.' ],
'XJ' => [ 'National telephone switchboard',
    'The national telephone switchboard number.' ],
);
sub get_codes { return \%code_hash; }

1;