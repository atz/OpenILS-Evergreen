package Business::EDI;

use strict;
use warnings;
use Carp;

use Data::Dumper;
our $verbose = 0;

sub new {
    my($class, %args) = @_;
    my $self = bless(\%args, $class);
    # $self->{args} = {};
    return $self;
}

########################################

package Business::EDI::ResponseTypeCode;

use strict;
use warnings;
use Carp;

our %code_hash = ();  # caching

sub init {
    my $self = shift;
    my $code = shift or return;
    my $codes = $self->get_codes();
    $codes->{$code} or return;
    $self->{code } = $code;
    $self->{label} = $codes->{$code}->[0];
    $self->{desc}  = $codes->{$code}->[1];
    return $self;
}

sub code  { my $self = shift; @_ and $self->{code } = shift; return $self->{code }; }
sub label { my $self = shift; @_ and $self->{label} = shift; return $self->{label}; }
sub desc  { my $self = shift; @_ and $self->{desc } = shift; return $self->{desc} ; }

sub get_codes {
    my $self = shift;
    %code_hash or %code_hash = (
    AA => ['Debit advice', 
            'Receiver of the payment message needs to return a debit advice in response to the payment message.'],
    AB => ['Message acknowledgement', 
            'Indicates that an acknowledgement relating to receipt of message is required.'],
    AC => ['Acknowledge - with detail and change', 
            'Acknowledge complete including changes.'],
    AD => ['Acknowledge - with detail, no change', 
            'Acknowledge complete without changes.'],
    AE => ['Debit advice for each transaction', 
            'A debit advice is requested for each transaction in the message.'],
    AF => ['Debit advice/message acknowledgement', 
            'The sender wishes to receive both a Debit Advice and an acknowledgement of receipt for a payment message.'],
    AG => ['Authentication', 
            'Authentication, by a party, of a document established for him by another party.'],
    AH => ['Debit advice/message acknowledgement for each transaction', 
            'A debit advice and message acknowledgement are requested for each transaction in the message.'],
    AI => ['Acknowledge only changes', 
            'Acknowledgement of changes only is required.'],
    AJ => ['Pending', 
            'Indication that the referenced offer or transaction (e.g. cargo booking or quotation request) is being dealt with.'],
    AP => ['Accepted', 
            'Indication that the referenced offer or transaction (e.g., cargo booking or quotation request) has been accepted.'],
    AQ => ['Response expected', 
            'The sender of the message expects a response.'],
    AR => ['Direct documentary credit collection', 
            'Documentary credit collection forwarded directly.'],
    AS => ['Credit advice and message acknowledgement', 
            'The receiver of the message is to acknowledge receipt of the message and sent a credit advice for each credit.'],
    CA => ['Conditionally accepted', 
            'Indication that the referenced offer or transaction (e.g., cargo booking or quotation request) has been accepted under conditions indicated in this message.'],
    CO => ['Confirmation of measurements', 
            'Indication that the message contains the physical measurements on which the charges will be based.'],
    NA => ['No acknowledgement needed', 
            'Specifies that no acknowledgement is needed in response to this message.'],
    RE => ['Rejected', 
            'Indication that the referenced offer or transaction (e.g., cargo booking or quotation request) is not accepted.'],
    UR => ['Credit advice', 
            'The message recipient is to send a credit advice in response to the message.'],
    US => ['Acknowledgement when error', 
            'An acknowledgement is requested when an error occurred.'],
    UT => ['Acknowledgment due to error', 
            'An acknowledgment is sent because an error was identified in the received message.'],
    UU => ['Alternate date', 
            'The solution proposed in the response applies to another date than the one requested.'],
    UV => ['Alternate service', 
            'The solution proposed in the response applies to another service than the one requested.'],
    );
    return \%code_hash;
}

sub new {
    my $class = shift;
    my $code = shift or carp "No response type code argument specified";
    $code or return;
    my $self = bless({}, $class);
    unless ($self->init($code)) {
        carp "init() failed for code '$code'";
        return;
    }
    return $self;
}

################################################################33
package Business::EDI::MessageFunctionCode;

use strict;
use warnings;
use Carp;

our %code_hash = ();  # caching

sub init {
    my $self = shift;
    my $code = shift or return;
    my $codes = $self->get_codes();
    $codes->{$code} or return;
    $self->{code } = $code;
    $self->{label} = $codes->{$code}->[0];
    $self->{desc}  = $codes->{$code}->[1];
    return $self;
}

sub code  { my $self = shift; @_ and $self->{code } = shift; return $self->{code }; }
sub label { my $self = shift; @_ and $self->{label} = shift; return $self->{label}; }
sub desc  { my $self = shift; @_ and $self->{desc } = shift; return $self->{desc} ; }

sub get_codes {
    my $self = shift;
    %code_hash or %code_hash = (
    1 => ['Cancellation', 
            'Message cancelling a previous transmission for a given transaction.'],
    2 => ['Addition', 
            'Message containing items to be added.'],
    3 => ['Deletion', 
            'Message containing items to be deleted.'],
    4 => ['Change', 
            'Message containing items to be changed.'],
    5 => ['Replace', 
            'Message replacing a previous message.'],
    6 => ['Confirmation', 
            'Message confirming the details of a previous transmission where such confirmation is required or recommended under the terms of a trading partner agreement.'],
    7 => ['Duplicate', 
            'The message is a duplicate of a previously generated message.'],
    8 => ['Status', 
            'Code indicating that the referenced message is a status.'],
    9 => ['Original', 
            'Initial transmission related to a given transaction.'],
    10 => ['Not found', 
            'Message whose reference number is not filed.'],
    11 => ['Response', 
            'Message responding to a previous message or document.'],
    12 => ['Not processed', 
            'Message indicating that the referenced message was received but not yet processed.'],
    13 => ['Request', 
            'Code indicating that the referenced message is a request.'],
    14 => ['Advance notification', 
            'Code indicating that the information contained in the message is an advance notification of information to follow.'],
    15 => ['Reminder', 
            'Repeated message transmission for reminding purposes.'],
    16 => ['Proposal', 
            'Message content is a proposal.'],
    17 => ['Cancel, to be reissued', 
            'Referenced transaction cancelled, reissued message will follow.'],
    18 => ['Reissue', 
            'New issue of a previous message (maybe cancelled).'],
    19 => ['Seller initiated change', 
            'Change information submitted by buyer but initiated by seller.'],
    20 => ['Replace heading section only', 
            'Message to replace the heading of a previous message.'],
    21 => ['Replace item detail and summary only', 
            'Message to replace item detail and summary of a previous message.'],
    22 => ['Final transmission', 
            'Final message in a related series of messages together making up a commercial, administrative or transport transaction.'],
    23 => ['Transaction on hold', 
            'Message not to be processed until further release information.'],
    24 => ['Delivery instruction', 
            'Delivery schedule message only used to transmit short-term delivery instructions.'],
    25 => ['Forecast', 
            'Delivery schedule message only used to transmit long-term schedule information.'],
    26 => ['Delivery instruction and forecast', 
            'Combination of codes 24 and 25.'],
    27 => ['Not accepted', 
            'Message to inform that the referenced message is not accepted by the recipient.'],
    28 => ['Accepted, with amendment in heading section', 
            'Message accepted but amended in heading section.'],
    29 => ['Accepted without amendment', 
            'Referenced message is entirely accepted.'],
    30 => ['Accepted, with amendment in detail section', 
            'Referenced message is accepted but amended in detail section.'],
    31 => ['Copy', 
            'Indicates that the message is a copy of an original message that has been sent, e.g. for action or information.'],
    32 => ['Approval', 
            'A message releasing an existing referenced message for action to the receiver.'],
    33 => ['Change in heading section', 
            'Message changing the referenced message heading section.'],
    34 => ['Accepted with amendment', 
            'The referenced message is accepted but amended.'],
    35 => ['Retransmission', 
            'Change-free transmission of a message previously sent.'],
    36 => ['Change in detail section', 
            'Message changing referenced detail section.'],
    37 => ['Reversal of a debit', 
            'Reversal of a previously posted debit.'],
    38 => ['Reversal of a credit', 
            'Reversal of a previously posted credit.'],
    39 => ['Reversal for cancellation', 
            'Code indicating that the referenced message is reversing a cancellation of a previous transmission for a given transaction.'],
    40 => ['Request for deletion', 
            'The message is given to inform the recipient to delete the referenced transaction.'],
    41 => ['Finishing/closing order', 
            'Last of series of call-offs.'],
    42 => ['Confirmation via specific means', 
            'Message confirming a transaction previously agreed via other means (e.g. phone).'],
    43 => ['Additional transmission', 
            'Message already transmitted via another communication channel. This transmission is to provide electronically processable data only.'],
    44 => ['Accepted without reserves', 
            'Message accepted without reserves.'],
    45 => ['Accepted with reserves', 
            'Message accepted with reserves.'],
    46 => ['Provisional', 
            'Message content is provisional.'],
    47 => ['Definitive', 
            'Message content is definitive.'],
    48 => ['Accepted, contents rejected', 
            'Message to inform that the previous message is received, but it cannot be processed due to regulations, laws, etc.'],
    49 => ['Settled dispute', 
            'The reported dispute is settled.'],
    50 => ['Withdraw', 
            'Message withdrawing a previously approved message.'],
    51 => ['Authorisation', 
            'Message authorising a message or transaction(s).'],
    52 => ['Proposed amendment', 
            'A code used to indicate an amendment suggested by the sender.'],
    53 => ['Test', 
            'Code indicating the message is to be considered as a test.'],
    54 => ['Extract', 
            'A subset of the original.'],
    55 => ['Notification only', 
            'The receiver may use the notification information for analysis only.'],
    56 => ['Advice of ledger booked items', 
            'An advice that items have been booked in the ledger.'],
    57 => ['Advice of items pending to be booked in the ledger', 
            'An advice that items are pending to be booked in the ledger.'],
    58 => ['Pre-advice of items requiring further information', 
            'A pre-advice that items require further information.'],
    59 => ['Pre-adviced items', 
            'A pre-advice of items.'],
    60 => ['No action since last message', 
            'Code indicating the fact that no action has taken place since the last message.'],
    61 => ['Complete schedule', 
            'The message function is a complete schedule.'],
    62 => ['Update schedule', 
            'The message function is an update to a schedule.'],
    63 => ['Not accepted, provisional', 
            'Not accepted, subject to confirmation.'],
    64 => ['Verification', 
            'The message is transmitted to verify information.'],
    65 => ['Unsettled dispute', 
            'To report an unsettled dispute.'],
    );
    return \%code_hash;
}

sub new {
    my $class = shift;
    my $code = shift or carp "No message function type code argument specified";
    $code or return;
    my $self = bless({}, $class);
    unless ($self->init($code)) {
        carp "init() failed for code '$code'";
        return;
    }
    return $self;
}

1;
