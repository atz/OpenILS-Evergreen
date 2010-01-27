BEGIN;

-- INSERT INTO config.upgrade_log (version) VALUES ('0133');  -- atz
-- commented out until finalized

CREATE TABLE acq.edi_message (
    id               SERIAL          PRIMARY KEY,
    account          INTEGER         NOT NULL
                                     REFERENCES acq.edi_account(id)
                                     DEFERRABLE INITIALLY DEFERRED,
    remote_file      TEXT            NOT NULL,
    created_time     TIMESTAMPTZ     NOT NULL DEFAULT now(),
    translated_time  TIMESTAMPTZ,
    processed_time   TIMESTAMPTZ,
    error_time       TIMESTAMPTZ,
    status           TEXT            NOT NULL DEFAULT 'new'
                                     CONSTRAINT status_value CHECK
                                     ( status IN (
                                        'new',          -- needs to be translated
                                        'translated',   -- needs to be processed
                                        'trans_error',  -- error in translation step
                                        'processed',    -- needs to have remote_file deleted
                                        'proc_error',   -- error in processing step
                                        'delete_error', -- error in deletion
                                        'done'          -- done
                                     )),
    edi              TEXT,
    jedi             TEXT,
    error            TEXT
);

COMMIT;
