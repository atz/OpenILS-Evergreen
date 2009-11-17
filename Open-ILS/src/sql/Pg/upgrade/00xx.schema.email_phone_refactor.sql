BEGIN;

-- INSERT INTO config.upgrade_log (version) VALUES ('00xx'); -- atz

CREATE TABLE actor.usr_phone (
    id           SERIAL PRIMARY KEY,
    usr          INT    NOT NULL REFERENCES actor.usr (id) DEFERRABLE INITIALLY DEFERRED,
    digits       TEXT,
    invalid_date TIMESTAMP WITH TIME ZONE,
    invalid_note TEXT,
    CONSTRAINT digits_once_per_usr UNIQUE (usr, digits)
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

-- now the data moving

INSERT INTO actor.usr_phone (usr, digits)
    SELECT id AS usr,     day_phone AS digits FROM actor.usr
        WHERE day_phone     IS NOT NULL
    UNION ALL
    SELECT id AS usr, evening_phone AS digits FROM actor.usr
        WHERE evening_phone IS NOT NULL AND evening_phone != day_phone -- if they're the same, then we already got it
    UNION ALL
    SELECT id AS usr,   other_phone AS digits FROM actor.usr
        WHERE other_phone   IS NOT NULL AND   other_phone != day_phone  AND other_phone != evening_phone -- if they're the same, then we already got it
    RETURNING actor.usr_phone (id, digits);

-- INSERT INTO actor.usr_phone (usr, digits)
--    SELECT id AS usr,     day_phone AS digits FROM actor.usr
--        WHERE day_phone     IS NOT NULL;
--
-- INSERT INTO actor.usr_phone (usr, digits)
--    SELECT id AS usr, evening_phone AS digits FROM actor.usr
--        WHERE evening_phone IS NOT NULL AND evening_phone != day_phone; -- if they're the same, then we already got it
--
-- INSERT INTO actor.usr_phone (usr, digits)
--    SELECT id AS usr,   other_phone AS digits FROM actor.usr
--        WHERE other_phone   IS NOT NULL AND   other_phone != day_phone  AND other_phone != evening_phone; -- if they're the same, then we already got it


-- TODO: populate *_phone_id before the DROPs
--       also, retaylor CONSTRAINTS

ALTER TABLE actor.usr
    DROP COLUMN day_phone,
    DROP COLUMN evening_phone,
    DROP COLUMN other_phone;

COMMIT;

