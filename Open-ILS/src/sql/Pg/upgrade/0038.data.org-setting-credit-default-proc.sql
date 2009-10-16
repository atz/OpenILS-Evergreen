BEGIN;

INSERT INTO config.upgrade_log (version) VALUES ('0038'); -- senator

INSERT INTO
    config.org_unit_setting_type ( name, label, description, datatype )
    VALUES (
        'global.credit.processor.default',
        'Credit card processing: Name default credit processor',
        'This might be "AuthorizeNet", "PayPal", etc.',
        'string'
    );


COMMIT;
