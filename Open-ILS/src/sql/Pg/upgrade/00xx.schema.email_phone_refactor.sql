BEGIN;

-- INSERT INTO config.upgrade_log (version) VALUES ('00xx'); -- atz

CREATE TABLE actor.usr_phone (
    id               SERIAL PRIMARY KEY,
    usr              INT    NOT NULL REFERENCES actor.usr (id)            DEFERRABLE INITIALLY DEFERRED,
--  phone_type       INT    NOT NULL REFERENCES actor.usr_phone_type (id) DEFERRABLE INITIALLY DEFERRED,
    digits           TEXT,
    usr_label        TEXT,
    voice_ok         BOOL   NOT NULL DEFAULT FALSE,
    invalid_date     TIMESTAMP WITH TIME ZONE,
    invalid_note     TEXT,
    sms_ok           BOOL   NOT NULL DEFAULT FALSE,
    sms_invalid_date TIMESTAMP WITH TIME ZONE,
    sms_invalid_note TEXT,
    CONSTRAINT digits_once_per_usr_and_type UNIQUE (usr, digits)
);

CREATE INDEX actor_usr_phone_usr_idx    ON actor.usr_phone (usr);
CREATE INDEX actor_usr_phone_digits_idx ON actor.usr_phone (digits);

COMMENT ON TABLE actor.usr_phone IS $$
/*
 * Copyright (C) 2009   Equinox Software, Inc.
 * Joe Atzberger
 *
 * usr_phone
 *
 * FK for actor.usr phone fields and many-to-one list of phone numbers.
 *
 * usr_setting capabilities for user assignment of a give phone number
 * to a specific type of notice is deferred, possibly to be added later.  
 * 
 * ****
 *
 * This program is free software; you can redistribute it and/or
 * modify it under the terms of the GNU General Public License
 * as published by the Free Software Foundation; either version 2
 * of the License, or (at your option) any later version.
 *
 * This program is distributed in the hope that it will be useful,
 * but WITHOUT ANY WARRANTY; without even the implied warranty of
 * MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
 * GNU General Public License for more details.
 */
$$;

ALTER TABLE actor.usr 
    ADD COLUMN     day_phone_id INT REFERENCES actor.usr_phone (id) ON DELETE CASCADE DEFERRABLE INITIALLY DEFERRED,
    ADD COLUMN evening_phone_id INT REFERENCES actor.usr_phone (id) ON DELETE CASCADE DEFERRABLE INITIALLY DEFERRED,
    ADD COLUMN   other_phone_id INT REFERENCES actor.usr_phone (id) ON DELETE CASCADE DEFERRABLE INITIALLY DEFERRED;

-- now the data moving: same kind of operations, 3 times.
-- We do NOT add the number a new entry for each type where it is populated
-- if the number is the same digits.

INSERT INTO actor.usr_phone (usr, digits)
    SELECT id,     day_phone FROM actor.usr
    WHERE     day_phone IS NOT NULL;

UPDATE actor.usr SET     day_phone_id = actor.usr_phone.id FROM actor.usr_phone
    WHERE actor.usr_phone.usr    = actor.usr.id
     AND  actor.usr_phone.digits = actor.usr.day_phone;


INSERT INTO actor.usr_phone (usr, digits)
    SELECT id, evening_phone FROM actor.usr
    WHERE evening_phone IS NOT NULL
      AND evening_phone != day_phone;

UPDATE actor.usr SET evening_phone_id = actor.usr_phone.id FROM actor.usr_phone
    WHERE actor.usr_phone.usr    = actor.usr.id
     AND  actor.usr_phone.digits = actor.usr.evening_phone;


INSERT INTO actor.usr_phone (usr, digits)
    SELECT id,   other_phone FROM actor.usr
    WHERE   other_phone IS NOT NULL
      AND   other_phone != day_phone
      AND   other_phone != evening_phone;

UPDATE actor.usr SET   other_phone_id = actor.usr_phone.id FROM actor.usr_phone
    WHERE actor.usr_phone.usr    = actor.usr.id
     AND  actor.usr_phone.digits = actor.usr.other_phone;

-- TODO: retaylor CONSTRAINTS

-- Commented out during testing
-- ALTER TABLE actor.usr
--     DROP COLUMN day_phone,
--     DROP COLUMN evening_phone,
--     DROP COLUMN other_phone;

COMMIT;

