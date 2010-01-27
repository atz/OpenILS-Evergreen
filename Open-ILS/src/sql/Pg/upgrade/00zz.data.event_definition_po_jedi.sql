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
        {"id-qualifier":"91","id":"3472205","reference":{"API":"3472205 0001"}},
        {"id":"3472205","reference":{"API":"3472205 0001"}}
    ],

    "vendor":[
        "[% target.provider.san %]",
        {"id-qualifier":"91", "reference":{"IA":"1865"}, "id":"[% target.provider.san %]"}
    ],

    "currency":"[% target.provider.currency_type %]",

    "items":[
        [% FOR li IN target.lineitems %]
        {
            "identifiers":[{"id-qualifier":"SA","id":"03-0010837"}],
            "price":[% PROCESS get_li_attr attr_name = ''estimated_price'' %],
            "desc":[
                {"BTI":"[% PROCESS get_li_attr attr_name = ''title''      %]"},
                {"BPU":"[% PROCESS get_li_attr attr_name = ''publisher''  %]"},
                {"BPD":"[% PROCESS get_li_attr attr_name = ''pubdate''    %]"},
                {"BPH":"[% PROCESS get_li_attr attr_name = ''pagination'' %]"}
            ],
            "quantity":[% li.lineitem_details.size %]
        },
        [% END %]
    ],

    "line_items":[% target.lineitems.size %]
}]
');

INSERT INTO action_trigger.environment (event_def, path) VALUES 
  ((SELECT id FROM action_trigger.event_definition WHERE name='PO JEDI'), 'lineitems.attributes'), 
  ((SELECT id FROM action_trigger.event_definition WHERE name='PO JEDI'), 'provider');

-- The environment insert has to happen here because it relies on subquerying the user-editable field "name" to
-- provide the FK.  Outside of this tranasaction, we cannot be sure the user hasn't changed the name to something else.

COMMIT;

