BEGIN;

-- INSERT INTO config.upgrade_log (version) VALUES ('0064');

INSERT INTO config.org_unit_setting_type ( name, label, description, datatype )
    VALUES 
( 'notice.telephony.enabled',
  'Enable or disable telephony',
  'Select "SIP" or "PSTN" to enable telephony notices over the respective carriers.  If "Off", no telephony is used.  If "PSTN", then notice.telphony.channels_available must be specified.',
  'text' ),

('notice.telephony.channels_available', 'PSTN channels to use for outgoing calls', 'Channels will be used in the order listed.', 'array'),

('notice.telephony.channel_last_used',  'Index of the channel last used from channels_available',
    'Note: This is not the channel value itself.  Index is zero-based.', 'integer'),

('notice.telephony.callfile_lines',     'Arbitrary line(s) to include in each notice callfile',
    'Line(s) must be valid for your target server and platform (e.g. Asterisk 1.4).', 'text'),

('notice.telephony.host.hostname', 'Telephony: hostname or IP', 'Specify the server that will make the calls', 'text'),
('notice.telephony.host.port',     'Telephony: port number',    'Server port where we find the listening agent. Default: 10080', 'integer'),
('notice.telephony.host.username', 'Telephony: username',       'Required by listening agent.', 'text'),
('notice.telephony.host.password', 'Telephony: password',       'Required by listening agent.', 'text')

COMMIT;

