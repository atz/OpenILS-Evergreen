BEGIN;

-- INSERT INTO config.upgrade_log (version) VALUES ('0058');
-- Commented out until this becomes official

INSERT INTO acq.event_definition (active, owner, name, hook, validator, reactor, cleanup_success, cleanup_failure, delay, delay_field, group_field, template) VALUES (true, 1, 'PO JEDI', 'format.po.jedi', 'NOOP_True', 'ProcessTemplate', NULL, NULL, '00:05:00', NULL, NULL, '[%- USE date -%]
[%- 
    # find a lineitem attribute by name and optional type
    BLOCK get_li_attr;
        FOR attr IN li.attributes;
            IF attr.attr_name == attr_name;
                IF !attr_type OR attr_type == attr.attr_type;
                    attr.attr_value;   
                    LAST;
                END;
            END;
        END;
    END 
-%]
[%# start JEDI document -%]
["order", {

    "po_number":[% target.id %],

    "date":"[% date.format(date.now, ''%Y%m%d'') %]",

    "buyer":[
//      {"id-qualifier":"91","id":"[% target.ordering_agency.mailing_address.san %]",
//       "reference":{"API":"[% target.ordering_agency.mailing_address.san %]"}},
        {"id":"[% target.ordering_agency.mailing_address.san %]",
         "reference":{"API":"[% target.ordering_agency.mailing_address.san %]"}}
    ],

    "vendor":[
        "[% target.provider.san %]",
        {"id-qualifier":"91", "reference":{"IA":"[% target.provider.id %]"}, "id":"[% target.provider.san %]"}
    ],

    "currency":"[% target.provider.currency_type %]",

    "items":[
        [% FOR li IN target.lineitems %]
        {
            "identifiers":[{"id-qualifier":"SA","id":"[% li.id %]"}],
            "price":[% PROCESS get_li_attr attr_name = ''estimated_price'' %],
            "desc":[
                {"BTI":"[% PROCESS get_li_attr attr_name = ''title''      %]"},
                {"BPU":"[% PROCESS get_li_attr attr_name = ''publisher''  %]"},
                {"BPD":"[% PROCESS get_li_attr attr_name = ''pubdate''    %]"},
                {"BPH":"[% PROCESS get_li_attr attr_name = ''pagination'' %]"}
            ],
            "quantity":[% li.lineitem_details.size %]
            // TODO: lineitem details (later)
        },
        [% END %]
    ],

    "line_items":[% target.lineitems.size %]
}]
');

/*
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
  ((SELECT id FROM action_trigger.event_definition WHERE name='PO JEDI'), 'ordering_agency.mailing_address'), 
  ((SELECT id FROM action_trigger.event_definition WHERE name='PO JEDI'), 'provider');

-- The environment insert has to happen here because it relies on subquerying the user-editable field "name" to
-- provide the FK.  Outside of this tranasaction, we cannot be sure the user hasn't changed the name to something else.

COMMIT;

