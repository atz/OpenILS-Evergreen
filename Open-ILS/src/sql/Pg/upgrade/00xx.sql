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
     cleanup_success, cleanup_failure, delay, delay_field, group_field, template)
    VALUES
    (TRUE, 1, 'Telephone Overdue Notice', 'checkout.due', 'NOOP_True', 'AstCall',
     DEFAULT, DEFAULT, DEFAULT, 'due_date', 'usr',
        '[%- user = target.0.usr -%]
phone number: [% user.day_phone %]
items: [% target.size %]
        '
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

