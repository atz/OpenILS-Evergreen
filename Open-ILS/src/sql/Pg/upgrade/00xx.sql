BEGIN;

-- INSERT INTO config.upgrade_log (version) VALUES ('0064');

INSERT INTO config.org_unit_setting_type ( name, label, description, datatype )
    VALUES 
( 'notice.telephony.enabled',
  'Enable or disable telephony',
  'Select "SIP" or "PTSN" to enable telephony features over the respective carriers.  If "Off", no telephony is used.  If "PTSN", then notice.telphony.channels_available must be specified.',
  'text' ),

COMMIT;

