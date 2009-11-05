/*
 * Copyright (C) 2004-2008  Georgia Public Library Service
 * Copyright (C) 2007-2008  Equinox Software, Inc.
 * Mike Rylander <miker@esilibrary.com> 
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
 *
 */

DROP SCHEMA action CASCADE;

BEGIN;

CREATE SCHEMA action;

CREATE TABLE action.in_house_use (
	id		SERIAL				PRIMARY KEY,
	item		BIGINT				NOT NULL REFERENCES asset.copy (id) DEFERRABLE INITIALLY DEFERRED,
	staff		INT				NOT NULL REFERENCES actor.usr (id) DEFERRABLE INITIALLY DEFERRED,
	org_unit	INT				NOT NULL REFERENCES actor.org_unit (id) DEFERRABLE INITIALLY DEFERRED,
	use_time	TIMESTAMP WITH TIME ZONE	NOT NULL DEFAULT NOW()
);
CREATE INDEX action_in_house_use_staff_idx      ON action.in_house_use ( staff );

CREATE TABLE action.non_cataloged_circulation (
	id		SERIAL				PRIMARY KEY,
	patron		INT				NOT NULL REFERENCES actor.usr (id) DEFERRABLE INITIALLY DEFERRED,
	staff		INT				NOT NULL REFERENCES actor.usr (id) DEFERRABLE INITIALLY DEFERRED,
	circ_lib	INT				NOT NULL REFERENCES actor.org_unit (id) DEFERRABLE INITIALLY DEFERRED,
	item_type	INT				NOT NULL REFERENCES config.non_cataloged_type (id) DEFERRABLE INITIALLY DEFERRED,
	circ_time	TIMESTAMP WITH TIME ZONE	NOT NULL DEFAULT NOW()
);
CREATE INDEX action_non_cat_circ_patron_idx ON action.non_cataloged_circulation ( patron );
CREATE INDEX action_non_cat_circ_staff_idx  ON action.non_cataloged_circulation ( staff );

CREATE TABLE action.non_cat_in_house_use (
	id		SERIAL				PRIMARY KEY,
	item_type	BIGINT				NOT NULL REFERENCES config.non_cataloged_type(id) DEFERRABLE INITIALLY DEFERRED,
	staff		INT				NOT NULL REFERENCES actor.usr (id) DEFERRABLE INITIALLY DEFERRED,
	org_unit	INT				NOT NULL REFERENCES actor.org_unit (id) DEFERRABLE INITIALLY DEFERRED,
	use_time	TIMESTAMP WITH TIME ZONE	NOT NULL DEFAULT NOW()
);
CREATE INDEX non_cat_in_house_use_staff_idx ON action.non_cat_in_house_use ( staff );

CREATE TABLE action.survey (
	id		SERIAL				PRIMARY KEY,
	owner		INT				NOT NULL REFERENCES actor.org_unit (id) DEFERRABLE INITIALLY DEFERRED,
	start_date	TIMESTAMP WITH TIME ZONE	NOT NULL DEFAULT NOW(),
	end_date	TIMESTAMP WITH TIME ZONE	NOT NULL DEFAULT NOW() + '10 years'::INTERVAL,
	usr_summary	BOOL				NOT NULL DEFAULT FALSE,
	opac		BOOL				NOT NULL DEFAULT FALSE,
	poll		BOOL				NOT NULL DEFAULT FALSE,
	required	BOOL				NOT NULL DEFAULT FALSE,
	name		TEXT				NOT NULL,
	description	TEXT				NOT NULL
);
CREATE UNIQUE INDEX asv_once_per_owner_idx ON action.survey (owner,name);

CREATE TABLE action.survey_question (
	id		SERIAL	PRIMARY KEY,
	survey		INT	NOT NULL REFERENCES action.survey DEFERRABLE INITIALLY DEFERRED,
	question	TEXT	NOT NULL
);

CREATE TABLE action.survey_answer (
	id		SERIAL	PRIMARY KEY,
	question	INT	NOT NULL REFERENCES action.survey_question DEFERRABLE INITIALLY DEFERRED,
	answer		TEXT	NOT NULL
);

CREATE SEQUENCE action.survey_response_group_id_seq;

CREATE TABLE action.survey_response (
	id			BIGSERIAL			PRIMARY KEY,
	response_group_id	INT,
	usr			INT, -- REFERENCES actor.usr
	survey			INT				NOT NULL REFERENCES action.survey DEFERRABLE INITIALLY DEFERRED,
	question		INT				NOT NULL REFERENCES action.survey_question DEFERRABLE INITIALLY DEFERRED,
	answer			INT				NOT NULL REFERENCES action.survey_answer DEFERRABLE INITIALLY DEFERRED,
	answer_date		TIMESTAMP WITH TIME ZONE,
	effective_date		TIMESTAMP WITH TIME ZONE	NOT NULL DEFAULT NOW()
);
CREATE INDEX action_survey_response_usr_idx ON action.survey_response ( usr );

CREATE OR REPLACE FUNCTION action.survey_response_answer_date_fixup () RETURNS TRIGGER AS '
BEGIN
	NEW.answer_date := NOW();
	RETURN NEW;
END;
' LANGUAGE 'plpgsql';
CREATE TRIGGER action_survey_response_answer_date_fixup_tgr
	BEFORE INSERT ON action.survey_response
	FOR EACH ROW
	EXECUTE PROCEDURE action.survey_response_answer_date_fixup ();


CREATE TABLE action.circulation (
	target_copy		BIGINT				NOT NULL, -- asset.copy.id
	circ_lib		INT				NOT NULL, -- actor.org_unit.id
	circ_staff		INT				NOT NULL, -- actor.usr.id
	checkin_staff		INT,					  -- actor.usr.id
	checkin_lib		INT,					  -- actor.org_unit.id
	renewal_remaining	INT				NOT NULL, -- derived from "circ duration" rule
	due_date		TIMESTAMP WITH TIME ZONE,
	stop_fines_time		TIMESTAMP WITH TIME ZONE,
	checkin_time		TIMESTAMP WITH TIME ZONE,
	create_time		TIMESTAMP WITH TIME ZONE    NOT NULL DEFAULT NOW(),
	duration		INTERVAL,				  -- derived from "circ duration" rule
	fine_interval		INTERVAL			NOT NULL DEFAULT '1 day'::INTERVAL, -- derived from "circ fine" rule
	recuring_fine		NUMERIC(6,2),				  -- derived from "circ fine" rule
	max_fine		NUMERIC(6,2),				  -- derived from "max fine" rule
	phone_renewal		BOOL				NOT NULL DEFAULT FALSE,
	desk_renewal		BOOL				NOT NULL DEFAULT FALSE,
	opac_renewal		BOOL				NOT NULL DEFAULT FALSE,
	duration_rule		TEXT				NOT NULL, -- name of "circ duration" rule
	recuring_fine_rule	TEXT				NOT NULL, -- name of "circ fine" rule
	max_fine_rule		TEXT				NOT NULL, -- name of "max fine" rule
	stop_fines		TEXT				CHECK (stop_fines IN (
	                                       'CHECKIN','CLAIMSRETURNED','LOST','MAXFINES','RENEW','LONGOVERDUE','CLAIMSNEVERCHECKEDOUT')),
	workstation         INT        REFERENCES actor.workstation(id)
	                               ON DELETE SET NULL
								   DEFERRABLE INITIALLY DEFERRED,
	checkin_workstation INT        REFERENCES actor.workstation(id)
	                               ON DELETE SET NULL
								   DEFERRABLE INITIALLY DEFERRED,
	checkin_scan_time   TIMESTAMP WITH TIME ZONE
) INHERITS (money.billable_xact);
ALTER TABLE action.circulation ADD PRIMARY KEY (id);
ALTER TABLE action.circulation
	ADD COLUMN parent_circ BIGINT
	REFERENCES action.circulation( id )
	DEFERRABLE INITIALLY DEFERRED;
CREATE INDEX circ_open_xacts_idx ON action.circulation (usr) WHERE xact_finish IS NULL;
CREATE INDEX circ_outstanding_idx ON action.circulation (usr) WHERE checkin_time IS NULL;
CREATE INDEX circ_checkin_time ON "action".circulation (checkin_time) WHERE checkin_time IS NOT NULL;
CREATE INDEX circ_circ_lib_idx ON "action".circulation (circ_lib);
CREATE INDEX circ_open_date_idx ON "action".circulation (xact_start) WHERE xact_finish IS NULL;
CREATE INDEX circ_all_usr_idx       ON action.circulation ( usr );
CREATE INDEX circ_circ_staff_idx    ON action.circulation ( circ_staff );
CREATE INDEX circ_checkin_staff_idx ON action.circulation ( checkin_staff );
CREATE UNIQUE INDEX circ_parent_idx ON action.circulation ( parent_circ ) WHERE parent_circ IS NOT NULL;


CREATE TRIGGER mat_summary_create_tgr AFTER INSERT ON action.circulation FOR EACH ROW EXECUTE PROCEDURE money.mat_summary_create ('circulation');
CREATE TRIGGER mat_summary_change_tgr AFTER UPDATE ON action.circulation FOR EACH ROW EXECUTE PROCEDURE money.mat_summary_update ();
CREATE TRIGGER mat_summary_remove_tgr AFTER DELETE ON action.circulation FOR EACH ROW EXECUTE PROCEDURE money.mat_summary_delete ();

CREATE OR REPLACE FUNCTION action.push_circ_due_time () RETURNS TRIGGER AS $$
BEGIN
    IF (EXTRACT(EPOCH FROM NEW.circ_duration)::INT % EXTRACT(EPOCH FROM '1 day'::INTERVAL)::INT) = 0 THEN
        NEW.due_date = (NEW.due_date::DATE + '1 day'::INTERVAL - '1 second'::INTERVAL)::TIMESTAMPTZ;
    END IF;

    RETURN NEW;
END;
$$ LANGUAGE PLPGSQL;

CREATE TRIGGER push_due_date_tgr BEFORE INSERT ON action.circulation FOR EACH ROW EXECUTE PROCEDURE action.push_circ_due_time();

CREATE TABLE action.aged_circulation (
	usr_post_code		TEXT,
	usr_home_ou		INT	NOT NULL,
	usr_profile		INT	NOT NULL,
	usr_birth_year		INT,
	copy_call_number	INT	NOT NULL,
	copy_location		INT	NOT NULL,
	copy_owning_lib		INT	NOT NULL,
	copy_circ_lib		INT	NOT NULL,
	copy_bib_record		BIGINT	NOT NULL,
	LIKE action.circulation

);
ALTER TABLE action.aged_circulation ADD PRIMARY KEY (id);
ALTER TABLE action.aged_circulation DROP COLUMN usr;
CREATE INDEX aged_circ_circ_lib_idx ON "action".aged_circulation (circ_lib);
CREATE INDEX aged_circ_start_idx ON "action".aged_circulation (xact_start);
CREATE INDEX aged_circ_copy_circ_lib_idx ON "action".aged_circulation (copy_circ_lib);
CREATE INDEX aged_circ_copy_owning_lib_idx ON "action".aged_circulation (copy_owning_lib);
CREATE INDEX aged_circ_copy_location_idx ON "action".aged_circulation (copy_location);

CREATE OR REPLACE VIEW action.all_circulation AS
    SELECT  id,usr_post_code, usr_home_ou, usr_profile, usr_birth_year, copy_call_number, copy_location,
        copy_owning_lib, copy_circ_lib, copy_bib_record, xact_start, xact_finish, target_copy,
        circ_lib, circ_staff, checkin_staff, checkin_lib, renewal_remaining, due_date,
        stop_fines_time, checkin_time, create_time, duration, fine_interval, recuring_fine,
        max_fine, phone_renewal, desk_renewal, opac_renewal, duration_rule, recuring_fine_rule,
        max_fine_rule, stop_fines, workstation, checkin_workstation, checkin_scan_time, parent_circ
      FROM  action.aged_circulation
            UNION ALL
    SELECT  DISTINCT circ.id,COALESCE(a.post_code,b.post_code) AS usr_post_code, p.home_ou AS usr_home_ou, p.profile AS usr_profile, EXTRACT(YEAR FROM p.dob)::INT AS usr_birth_year,
        cp.call_number AS copy_call_number, cp.location AS copy_location, cn.owning_lib AS copy_owning_lib, cp.circ_lib AS copy_circ_lib,
        cn.record AS copy_bib_record, circ.xact_start, circ.xact_finish, circ.target_copy, circ.circ_lib, circ.circ_staff, circ.checkin_staff,
        circ.checkin_lib, circ.renewal_remaining, circ.due_date, circ.stop_fines_time, circ.checkin_time, circ.create_time, circ.duration,
        circ.fine_interval, circ.recuring_fine, circ.max_fine, circ.phone_renewal, circ.desk_renewal, circ.opac_renewal, circ.duration_rule,
        circ.recuring_fine_rule, circ.max_fine_rule, circ.stop_fines, circ.workstation, circ.checkin_workstation, circ.checkin_scan_time,
        circ.parent_circ
      FROM  action.circulation circ
        JOIN asset.copy cp ON (circ.target_copy = cp.id)
        JOIN asset.call_number cn ON (cp.call_number = cn.id)
        JOIN actor.usr p ON (circ.usr = p.id)
        LEFT JOIN actor.usr_address a ON (p.mailing_address = a.id)
        LEFT JOIN actor.usr_address b ON (p.billing_address = a.id);

CREATE OR REPLACE FUNCTION action.age_circ_on_delete () RETURNS TRIGGER AS $$
DECLARE
found char := 'N';
BEGIN

    -- If there are any renewals for this circulation, don't archive or delete
    -- it yet.   We'll do so later, when we archive and delete the renewals.

    SELECT 'Y' INTO found
    FROM action.circulation
    WHERE parent_circ = OLD.id
    LIMIT 1;

    IF found = 'Y' THEN
        RETURN NULL;  -- don't delete
	END IF;

    -- Archive a copy of the old row to action.aged_circulation

    INSERT INTO action.aged_circulation
        (id,usr_post_code, usr_home_ou, usr_profile, usr_birth_year, copy_call_number, copy_location,
        copy_owning_lib, copy_circ_lib, copy_bib_record, xact_start, xact_finish, target_copy,
        circ_lib, circ_staff, checkin_staff, checkin_lib, renewal_remaining, due_date,
        stop_fines_time, checkin_time, create_time, duration, fine_interval, recuring_fine,
        max_fine, phone_renewal, desk_renewal, opac_renewal, duration_rule, recuring_fine_rule,
        max_fine_rule, stop_fines, workstation, checkin_workstation, checkin_scan_time, parent_circ)
      SELECT
        id,usr_post_code, usr_home_ou, usr_profile, usr_birth_year, copy_call_number, copy_location,
        copy_owning_lib, copy_circ_lib, copy_bib_record, xact_start, xact_finish, target_copy,
        circ_lib, circ_staff, checkin_staff, checkin_lib, renewal_remaining, due_date,
        stop_fines_time, checkin_time, create_time, duration, fine_interval, recuring_fine,
        max_fine, phone_renewal, desk_renewal, opac_renewal, duration_rule, recuring_fine_rule,
        max_fine_rule, stop_fines, workstation, checkin_workstation, checkin_scan_time, parent_circ
        FROM action.all_circulation WHERE id = OLD.id;

    RETURN OLD;
END;
$$ LANGUAGE 'plpgsql';

CREATE TRIGGER action_circulation_aging_tgr
	BEFORE DELETE ON action.circulation
	FOR EACH ROW
	EXECUTE PROCEDURE action.age_circ_on_delete ();


CREATE OR REPLACE FUNCTION action.age_parent_circ_on_delete () RETURNS TRIGGER AS $$
BEGIN

    -- Having deleted a renewal, we can delete the original circulation (or a previous
    -- renewal, if that's what parent_circ is pointing to).  That deletion will trigger
    -- deletion of any prior parents, etc. recursively.

    IF OLD.parent_circ IS NOT NULL THEN
        DELETE FROM action.circulation
        WHERE id = OLD.parent_circ;
    END IF;

    RETURN OLD;
END;
$$ LANGUAGE 'plpgsql';

CREATE TRIGGER age_parent_circ
	AFTER DELETE ON action.circulation
	FOR EACH ROW
	EXECUTE PROCEDURE action.age_parent_circ_on_delete ();


CREATE OR REPLACE VIEW action.open_circulation AS
	SELECT	*
	  FROM	action.circulation
	  WHERE	checkin_time IS NULL
	  ORDER BY due_date;
		

CREATE OR REPLACE VIEW action.billable_circulations AS
	SELECT	*
	  FROM	action.circulation
	  WHERE	xact_finish IS NULL;

CREATE VIEW stats.fleshed_circulation AS
        SELECT  c.*,
                CAST(c.xact_start AS DATE) AS start_date_day,
                CAST(c.xact_finish AS DATE) AS finish_date_day,
                DATE_TRUNC('hour', c.xact_start) AS start_date_hour,
                DATE_TRUNC('hour', c.xact_finish) AS finish_date_hour,
                cp.call_number_label,
                cp.owning_lib,
                cp.item_lang,
                cp.item_type,
                cp.item_form
        FROM    "action".circulation c
                JOIN stats.fleshed_copy cp ON (cp.id = c.target_copy);


CREATE OR REPLACE FUNCTION action.circulation_claims_returned () RETURNS TRIGGER AS $$
BEGIN
	IF OLD.stop_fines IS NULL OR OLD.stop_fines <> NEW.stop_fines THEN
		IF NEW.stop_fines = 'CLAIMSRETURNED' THEN
			UPDATE actor.usr SET claims_returned_count = claims_returned_count + 1 WHERE id = NEW.usr;
		END IF;
		IF NEW.stop_fines = 'CLAIMSNEVERCHECKEDOUT' THEN
			UPDATE actor.usr SET claims_never_checked_out_count = claims_never_checked_out_count + 1 WHERE id = NEW.usr;
		END IF;
		IF NEW.stop_fines = 'LOST' THEN
			UPDATE asset.copy SET status = 3 WHERE id = NEW.target_copy;
		END IF;
	END IF;
	RETURN NEW;
END;
$$ LANGUAGE 'plpgsql';
CREATE TRIGGER action_circulation_stop_fines_tgr
	BEFORE UPDATE ON action.circulation
	FOR EACH ROW
	EXECUTE PROCEDURE action.circulation_claims_returned ();

CREATE TABLE action.hold_request_cancel_cause (
    id      SERIAL  PRIMARY KEY,
    label   TEXT    UNIQUE
);
INSERT INTO action.hold_request_cancel_cause (id,label) VALUES (1,'Untargeted expiration');
INSERT INTO action.hold_request_cancel_cause (id,label) VALUES (2,'Hold Shelf expiration');
INSERT INTO action.hold_request_cancel_cause (id,label) VALUES (3,'Patron via phone');
INSERT INTO action.hold_request_cancel_cause (id,label) VALUES (4,'Patron in person');
INSERT INTO action.hold_request_cancel_cause (id,label) VALUES (5,'Staff forced');
INSERT INTO action.hold_request_cancel_cause (id,label) VALUES (6,'Patron via OPAC');
SELECT SETVAL('action.hold_request_cancel_cause_id_seq', 100);

CREATE TABLE action.hold_request (
	id			SERIAL				PRIMARY KEY,
	request_time		TIMESTAMP WITH TIME ZONE	NOT NULL DEFAULT NOW(),
	capture_time		TIMESTAMP WITH TIME ZONE,
	fulfillment_time	TIMESTAMP WITH TIME ZONE,
	checkin_time		TIMESTAMP WITH TIME ZONE,
	return_time		TIMESTAMP WITH TIME ZONE,
	prev_check_time		TIMESTAMP WITH TIME ZONE,
	expire_time		TIMESTAMP WITH TIME ZONE,
	cancel_time		TIMESTAMP WITH TIME ZONE,
	cancel_cause	INT REFERENCES action.hold_request_cancel_cause (id) ON DELETE SET NULL DEFERRABLE INITIALLY DEFERRED,
	cancel_note		TEXT,
	target			BIGINT				NOT NULL, -- see hold_type
	current_copy		BIGINT				REFERENCES asset.copy (id) ON DELETE SET NULL DEFERRABLE INITIALLY DEFERRED,
	fulfillment_staff	INT				REFERENCES actor.usr (id) DEFERRABLE INITIALLY DEFERRED,
	fulfillment_lib		INT				REFERENCES actor.org_unit (id) DEFERRABLE INITIALLY DEFERRED,
	request_lib		INT				NOT NULL REFERENCES actor.org_unit (id) DEFERRABLE INITIALLY DEFERRED,
	requestor		INT				NOT NULL REFERENCES actor.usr (id) DEFERRABLE INITIALLY DEFERRED,
	usr			INT				NOT NULL REFERENCES actor.usr (id) DEFERRABLE INITIALLY DEFERRED,
	selection_ou		INT				NOT NULL,
	selection_depth		INT				NOT NULL DEFAULT 0,
	pickup_lib		INT				NOT NULL REFERENCES actor.org_unit DEFERRABLE INITIALLY DEFERRED,
	hold_type		TEXT				NOT NULL CHECK (hold_type IN ('M','T','V','C')),
	holdable_formats	TEXT,
	phone_notify		TEXT,
	email_notify		BOOL				NOT NULL DEFAULT TRUE,
	frozen			BOOL				NOT NULL DEFAULT FALSE,
	thaw_date		TIMESTAMP WITH TIME ZONE,
	shelf_time		TIMESTAMP WITH TIME ZONE,
    cut_in_line     BOOL,
	mint_condition  BOOL NOT NULL DEFAULT TRUE,
	shelf_expire_time TIMESTAMPTZ
);

CREATE INDEX hold_request_target_idx ON action.hold_request (target);
CREATE INDEX hold_request_usr_idx ON action.hold_request (usr);
CREATE INDEX hold_request_pickup_lib_idx ON action.hold_request (pickup_lib);
CREATE INDEX hold_request_current_copy_idx ON action.hold_request (current_copy);
CREATE INDEX hold_request_prev_check_time_idx ON action.hold_request (prev_check_time);
CREATE INDEX hold_request_fulfillment_staff_idx ON action.hold_request ( fulfillment_staff );
CREATE INDEX hold_request_requestor_idx         ON action.hold_request ( requestor );


CREATE TABLE action.hold_request_note (

    id     BIGSERIAL PRIMARY KEY,
    hold   BIGINT    NOT NULL REFERENCES action.hold_request (id)
                              ON DELETE CASCADE
                              DEFERRABLE INITIALLY DEFERRED,
    title  TEXT      NOT NULL,
    body   TEXT      NOT NULL,
    slip   BOOL      NOT NULL DEFAULT FALSE,
    pub    BOOL      NOT NULL DEFAULT FALSE,
    staff  BOOL      NOT NULL DEFAULT FALSE  -- created by staff

);
CREATE INDEX ahrn_hold_idx ON action.hold_request_note (hold);


CREATE TABLE action.hold_notification (
	id		SERIAL				PRIMARY KEY,
	hold		INT				NOT NULL REFERENCES action.hold_request (id)
									ON DELETE CASCADE
									DEFERRABLE INITIALLY DEFERRED,
	notify_staff	INT			REFERENCES actor.usr (id) DEFERRABLE INITIALLY DEFERRED,
	notify_time	TIMESTAMP WITH TIME ZONE	NOT NULL DEFAULT NOW(),
	method		TEXT				NOT NULL, -- email address or phone number
	note		TEXT
);
CREATE INDEX ahn_hold_idx ON action.hold_notification (hold);
CREATE INDEX ahn_notify_staff_idx ON action.hold_notification ( notify_staff );

CREATE TABLE action.hold_copy_map (
	id		SERIAL	PRIMARY KEY,
	hold		INT	NOT NULL REFERENCES action.hold_request (id) ON DELETE CASCADE DEFERRABLE INITIALLY DEFERRED,
	target_copy	BIGINT	NOT NULL REFERENCES asset.copy (id) ON DELETE CASCADE DEFERRABLE INITIALLY DEFERRED,
	CONSTRAINT copy_once_per_hold UNIQUE (hold,target_copy)
);
-- CREATE INDEX acm_hold_idx ON action.hold_copy_map (hold);
CREATE INDEX acm_copy_idx ON action.hold_copy_map (target_copy);

CREATE TABLE action.transit_copy (
	id			SERIAL				PRIMARY KEY,
	source_send_time	TIMESTAMP WITH TIME ZONE,
	dest_recv_time		TIMESTAMP WITH TIME ZONE,
	target_copy		BIGINT				NOT NULL REFERENCES asset.copy (id) ON DELETE CASCADE DEFERRABLE INITIALLY DEFERRED,
	source			INT				NOT NULL REFERENCES actor.org_unit (id) DEFERRABLE INITIALLY DEFERRED,
	dest			INT				NOT NULL REFERENCES actor.org_unit (id) DEFERRABLE INITIALLY DEFERRED,
	prev_hop		INT				REFERENCES action.transit_copy (id) DEFERRABLE INITIALLY DEFERRED,
	copy_status		INT				NOT NULL REFERENCES config.copy_status (id) DEFERRABLE INITIALLY DEFERRED,
	persistant_transfer	BOOL				NOT NULL DEFAULT FALSE,
	prev_dest       INT				NOT NULL REFERENCES actor.org_unit (id) DEFERRABLE INITIALLY DEFERRED
);
CREATE INDEX active_transit_dest_idx ON "action".transit_copy (dest); 
CREATE INDEX active_transit_source_idx ON "action".transit_copy (source);
CREATE INDEX active_transit_cp_idx ON "action".transit_copy (target_copy);


CREATE TABLE action.hold_transit_copy (
	hold	INT	REFERENCES action.hold_request (id) ON DELETE SET NULL DEFERRABLE INITIALLY DEFERRED
) INHERITS (action.transit_copy);
ALTER TABLE action.hold_transit_copy ADD PRIMARY KEY (id);
ALTER TABLE action.hold_transit_copy ADD CONSTRAINT ahtc_tc_fkey FOREIGN KEY (target_copy) REFERENCES asset.copy (id) ON DELETE CASCADE DEFERRABLE INITIALLY DEFERRED;
CREATE INDEX active_hold_transit_dest_idx ON "action".hold_transit_copy (dest);
CREATE INDEX active_hold_transit_source_idx ON "action".hold_transit_copy (source);
CREATE INDEX active_hold_transit_cp_idx ON "action".hold_transit_copy (target_copy);


CREATE TABLE action.unfulfilled_hold_list (
	id		BIGSERIAL			PRIMARY KEY,
	current_copy	BIGINT				NOT NULL,
	hold		INT				NOT NULL,
	circ_lib	INT				NOT NULL,
	fail_time	TIMESTAMP WITH TIME ZONE	NOT NULL DEFAULT NOW()
);
CREATE INDEX uhr_hold_idx ON action.unfulfilled_hold_list (hold);

CREATE OR REPLACE VIEW action.unfulfilled_hold_loops AS
    SELECT  u.hold,
            c.circ_lib,
            count(*)
      FROM  action.unfulfilled_hold_list u
            JOIN asset.copy c ON (c.id = u.current_copy)
      GROUP BY 1,2;

CREATE OR REPLACE VIEW action.unfulfilled_hold_min_loop AS
    SELECT  hold,
            min(count)
      FROM  action.unfulfilled_hold_loops
      GROUP BY 1;

CREATE OR REPLACE VIEW action.unfulfilled_hold_innermost_loop AS
    SELECT  DISTINCT l.*
      FROM  action.unfulfilled_hold_loops l
            JOIN action.unfulfilled_hold_min_loop m USING (hold)
      WHERE l.count = m.min;


COMMIT;

