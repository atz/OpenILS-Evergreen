BEGIN;

-- INSERT INTO config.upgrade_log (version) VALUES ('0058');
-- Commented out until this becomes official

INSERT INTO acq.event_definition (active, owner, name, hook, validator, reactor, cleanup_success, cleanup_failure, delay, delay_field, group_field, template) VALUES (true, 1, 'PO JEDI', 'format.po.jedi', 'NOOP_True', 'ProcessTemplate', NULL, NULL, '00:05:00', NULL, NULL,
$$[%- USE date -%]
[%# start JEDI document -%]
[%- BLOCK big_block -%]
{
   "recipient":"[% target.provider.san %]",
   "sender":"[% target.ordering_agency.mailing_address.san %]",
   "body": [{
     "ORDERS":[ "order", {
        "po_number":[% target.id %],
        "date":"[% date.format(date.now, '%Y%m%d') %]",
        "buyer":[{
            [%- IF target.provider.edi_default.vendcode -%]
            "id":"[% target.ordering_agency.mailing_address.san _ ' ' _ target.provider.edi_default.vendcode %]", 
            "id-qualifier": 91
            [%- ELSE -%]
            "id":"[% target.ordering_agency.mailing_address.san %]"
            [%- END  -%]
        }],
        "vendor":[ 
            [%- # target.provider.name (target.provider.id) -%]
            "[% target.provider.san %]",
            {"id-qualifier": 92, "id":"[% target.provider.id %]"}
        ],
        "currency":"[% target.provider.currency_type %]",
        "items":[
        [% FOR li IN target.lineitems %]
        {
            "identifiers":[
                {"id-qualifier":"SA","id":"[% li.id %]"},
                {"id-qualifier":"IB","id":"[% helpers.get_li_attr('isbn', li.attributes) %]"}
            ],
            "price":[% helpers.get_li_attr('estimated_price', '', li.attributes) %],
            "desc":[
                {"BTI":"[% helpers.get_li_attr('title',     '', li.attributes) %]"}, 
                {"BPU":"[% helpers.get_li_attr('publisher', '', li.attributes) %]"},
                {"BPD":"[% helpers.get_li_attr('pubdate',   '', li.attributes) %]"},
                {"BPH":"[% helpers.get_li_attr('pagination','', li.attributes) %]"}
            ],
            "quantity":[% li.lineitem_details.size %]
        [%-# TODO: lineitem details (later) -%]
        }[% UNLESS loop.last %],[% END %]
        [% END %]
        ],
        "line_items":[% target.lineitems.size %]
     }]  [% # close ORDERS array %]
   }]    [% # close  body  array %]
}
[% END %]
[% tempo = PROCESS big_block; helpers.escape_json(tempo) %]
$$
);

/*
Other possible TT formations (e.g. in "buyer"):
[%- "reference":{"91": "[% target.provider.edi_default.vendcode %]"} -%]
[%- "reference":{"API":"target.ordering_agency.mailing_address.san"} -%]

// API : additional party identification -- supplier’s code for library acct or dept (EAN code) 
// IA  : internal vendor number (vendor profile number)
// VA  : VAT registered number.... TODO

BUYER id-qualifier:
 9  = EAN - location number -- not the same as EAN-13 barcode
31B = US book trade SANs (Standard Address Numbers aka EDItEUR code) - TRANSLATOR DEFAULT!
91  = Assigned by supplier or supplier’s agent
92  = Assigned by buyer

ITEM id-qualifier (Item number type, coded):
EN = EAN-13 article number - 13 digit barcode
IB = ISBN (International Standard Book   Number)
IM = ISMN (International Standard Music  Number)
IS = ISSN (International Standard Serial Number): use only in a continuation order message coded 22C in BGM DE 1001, to identify the series to which the order applies
MF = manufacturer’s article number
SA = supplier’s article number
*/


INSERT INTO action_trigger.environment (event_def, path) VALUES 
  ((SELECT id FROM action_trigger.event_definition WHERE name='PO JEDI'), 'lineitems.attributes'), 
  ((SELECT id FROM action_trigger.event_definition WHERE name='PO JEDI'), 'lineitems.lineitem_details'), 
  ((SELECT id FROM action_trigger.event_definition WHERE name='PO JEDI'), 'lineitems.lineitem_notes'), 
  ((SELECT id FROM action_trigger.event_definition WHERE name='PO JEDI'), 'ordering_agency.mailing_address'), 
  ((SELECT id FROM action_trigger.event_definition WHERE name='PO JEDI'), 'provider'),
  ((SELECT id FROM action_trigger.event_definition WHERE name='PO JEDI'), 'provider.edi_default');

-- The environment insert has to happen here because it relies on subquerying the user-editable field "name" to
-- provide the FK.  Outside of this transaction, we cannot be sure the user hasn't changed the name to something else.

COMMIT;

