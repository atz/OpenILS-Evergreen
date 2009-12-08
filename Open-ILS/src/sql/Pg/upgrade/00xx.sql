BEGIN;

-- INSERT INTO config.upgrade_log (version) VALUES ('0064');

INSERT INTO config.org_unit_setting_type ( name, label, description, datatype )
    VALUES 
--
-- DELETE FROM config.org_unit_setting_type where name LIKE 'notice.telephony.%' AND name != 'notice.telephony.callfile_lines';
--
----------- All this stuff is in opensrf.xml now:
-- ( 'notice.telephony.enabled',
--   'Telephony: Enable or disable',
--   'Select "SIP" or "PSTN" to enable telephony notices over the respective carriers.  If "Off", no telephony is used.  If "PSTN", then notice.telphony.channels_available must be specified.',
--   'string' ),
-- 
-- ('notice.telephony.channels_available', 'Telephony: PSTN channels to use for outgoing calls', 'Channels will be used in the order listed.', 'array'),
-- 
-- ('notice.telephony.channel_last_used',  'Telephony: Index of the channel last used from channels_available',
--     'Note: This is not the channel value itself.  Index is zero-based.', 'integer'),
-- ('notice.telephony.host.hostname', 'Telephony: hostname or IP', 'Specify the server that will make the calls', 'string'),
-- ('notice.telephony.host.port',     'Telephony: port number',    'Server port where we find the listening agent. Default: 10080', 'integer'),
-- ('notice.telephony.host.username', 'Telephony: username',       'Required by listening agent.', 'string'),
-- ('notice.telephony.host.password', 'Telephony: password',       'Required by listening agent.', 'string'),

('notice.telephony.callfile_lines',     'Telephony: Arbitrary line(s) to include in each notice callfile',
    'This overrides lines from opensrf.xml.  Line(s) must be valid for your target server and platform (e.g. Asterisk 1.4).', 'string');


INSERT INTO action_trigger.reactor VALUES
    ('AstCall', 'Possibly place a phone call with Asterisk');

INSERT INTO action_trigger.event_definition
    (active, owner, name, hook, validator, reactor,
     cleanup_success, cleanup_failure, delay, delay_field, group_field,
     template,
     max_delay, granularity, usr_field, opt_in_setting)
    VALUES
    (TRUE, 1, 'Telephone Overdue Notice', 'checkout.due', 'NOOP_True', 'AstCall',
     DEFAULT, DEFAULT, DEFAULT, 'due_date', 'usr',
        '[% phone = target.0.usr.day_phone | replace(''[\s\-\(\)]'', '''') -%] 
[% IF phone.match(''^[2-9]'') %][% country = 1 %][% ELSE %][% country = '''' %][% END -%]
Channel: [% channel_prefix %]/[% country %][% phone %]
Context: overdue-test
MaxRetries: 1
RetryTime: 60
WaitTime: 30
Extension: 10
Archive: 1
Set: eg_user_id=[% target.0.usr.id %]
Set: items=[% target.size %]
Set: titlestring=[% titles = [] %][% FOR circ IN target %][% titles.push(circ.target_copy.call_number.record.simple_record.title) %][% END %][% titles.join(". ") %]',
    DEFAULT, DEFAULT, DEFAULT, DEFAULT
    -- FIXME: these fields are new, designed in part for this feature... but what goes in them?
    );

INSERT INTO action_trigger.environment
    (id, event_def, path) VALUES
    (DEFAULT,
    (SELECT id FROM action_trigger.event_definition
        WHERE name = 'Telephone Overdue Notice'),
    'target_copy.call_number.record.simple_record'),
    (DEFAULT,
    (SELECT id FROM action_trigger.event_definition
        WHERE name = 'Telephone Overdue Notice'),
    'usr')
;

COMMIT;

