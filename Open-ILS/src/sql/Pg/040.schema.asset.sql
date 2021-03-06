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

DROP SCHEMA IF EXISTS asset CASCADE;

BEGIN;

CREATE SCHEMA asset;

CREATE TABLE asset.copy_location (
	id		SERIAL	PRIMARY KEY,
	name		TEXT	NOT NULL,
	owning_lib	INT	NOT NULL REFERENCES actor.org_unit (id) DEFERRABLE INITIALLY DEFERRED,
	holdable	BOOL	NOT NULL DEFAULT TRUE,
	hold_verify	BOOL	NOT NULL DEFAULT FALSE,
	opac_visible	BOOL	NOT NULL DEFAULT TRUE,
	circulate	BOOL	NOT NULL DEFAULT TRUE,
	label_prefix	TEXT,
	label_suffix	TEXT,
	CONSTRAINT acl_name_once_per_lib UNIQUE (name, owning_lib)
);

CREATE TABLE asset.copy_location_order
(
        id              SERIAL           PRIMARY KEY,
        location        INT              NOT NULL
                                             REFERENCES asset.copy_location
                                             ON DELETE CASCADE
                                             DEFERRABLE INITIALLY DEFERRED,
        org             INT              NOT NULL
                                             REFERENCES actor.org_unit
                                             ON DELETE CASCADE
                                             DEFERRABLE INITIALLY DEFERRED,
        position        INT              NOT NULL DEFAULT 0,
        CONSTRAINT acplo_once_per_org UNIQUE ( location, org )
);

CREATE TABLE asset.copy (
	id		BIGSERIAL			PRIMARY KEY,
	circ_lib	INT				NOT NULL REFERENCES actor.org_unit (id) DEFERRABLE INITIALLY DEFERRED,
	creator		BIGINT				NOT NULL,
	call_number	BIGINT				NOT NULL,
	editor		BIGINT				NOT NULL,
	create_date	TIMESTAMP WITH TIME ZONE	DEFAULT NOW(),
	edit_date	TIMESTAMP WITH TIME ZONE	DEFAULT NOW(),
	copy_number	INT,
	status		INT				NOT NULL DEFAULT 0 REFERENCES config.copy_status (id) DEFERRABLE INITIALLY DEFERRED,
	location	INT				NOT NULL DEFAULT 1 REFERENCES asset.copy_location (id) DEFERRABLE INITIALLY DEFERRED,
	loan_duration	INT				NOT NULL CHECK ( loan_duration IN (1,2,3) ),
	fine_level	INT				NOT NULL CHECK ( fine_level IN (1,2,3) ),
	age_protect	INT,
	circulate	BOOL				NOT NULL DEFAULT TRUE,
	deposit		BOOL				NOT NULL DEFAULT FALSE,
	ref		BOOL				NOT NULL DEFAULT FALSE,
	holdable	BOOL				NOT NULL DEFAULT TRUE,
	deposit_amount	NUMERIC(6,2)			NOT NULL DEFAULT 0.00,
	price		NUMERIC(8,2),
	barcode		TEXT				NOT NULL,
	circ_modifier	TEXT,
	circ_as_type	TEXT,
	dummy_title	TEXT,
	dummy_author	TEXT,
	alert_message	TEXT,
	opac_visible	BOOL				NOT NULL DEFAULT TRUE,
	deleted		BOOL				NOT NULL DEFAULT FALSE,
	floating		BOOL				NOT NULL DEFAULT FALSE,
	dummy_isbn      TEXT,
	status_changed_time TIMESTAMP WITH TIME ZONE,
	mint_condition      BOOL        NOT NULL DEFAULT TRUE,
    cost    NUMERIC(8,2)
);
CREATE UNIQUE INDEX copy_barcode_key ON asset.copy (barcode) WHERE deleted = FALSE OR deleted IS FALSE;
CREATE INDEX cp_cn_idx ON asset.copy (call_number);
CREATE INDEX cp_avail_cn_idx ON asset.copy (call_number);
CREATE INDEX cp_creator_idx  ON asset.copy ( creator );
CREATE INDEX cp_editor_idx   ON asset.copy ( editor );
CREATE RULE protect_copy_delete AS ON DELETE TO asset.copy DO INSTEAD UPDATE asset.copy SET deleted = TRUE WHERE OLD.id = asset.copy.id;

CREATE TABLE asset.opac_visible_copies (
  id        BIGINT primary key, -- copy id
  record    BIGINT,
  circ_lib  INTEGER
);
COMMENT ON TABLE asset.opac_visible_copies IS $$
Materialized view of copies that are visible in the OPAC, used by
search.query_parser_fts() to speed up OPAC visibility checks on large
databases.  Contents are maintained by a set of triggers.
$$;
CREATE INDEX opac_visible_copies_idx1 on asset.opac_visible_copies (record, circ_lib);

CREATE OR REPLACE FUNCTION asset.acp_status_changed()
RETURNS TRIGGER AS $$
BEGIN
    IF NEW.status <> OLD.status THEN
        NEW.status_changed_time := now();
    END IF;
    RETURN NEW;
END;
$$ LANGUAGE plpgsql;

CREATE TRIGGER acp_status_changed_trig
    BEFORE UPDATE ON asset.copy
    FOR EACH ROW EXECUTE PROCEDURE asset.acp_status_changed();

CREATE TABLE asset.stat_cat_entry_transparency_map (
	id			BIGSERIAL	PRIMARY KEY,
	stat_cat		INT		NOT NULL, -- needs ON DELETE CASCADE
	stat_cat_entry		INT		NOT NULL, -- needs ON DELETE CASCADE
	owning_transparency	INT		NOT NULL, -- needs ON DELETE CASCADE
	CONSTRAINT scte_once_per_trans UNIQUE (owning_transparency,stat_cat)
);

CREATE TABLE asset.stat_cat (
	id		SERIAL	PRIMARY KEY,
	owner		INT	NOT NULL,
	opac_visible	BOOL	NOT NULL DEFAULT FALSE,
	name		TEXT	NOT NULL,
	required	BOOL	NOT NULL DEFAULT FALSE,
	CONSTRAINT sc_once_per_owner UNIQUE (owner,name)
);

CREATE TABLE asset.stat_cat_entry (
	id		SERIAL	PRIMARY KEY,
        stat_cat        INT     NOT NULL,
	owner		INT	NOT NULL,
	value		TEXT	NOT NULL,
	CONSTRAINT sce_once_per_owner UNIQUE (stat_cat,owner,value)
);

CREATE TABLE asset.stat_cat_entry_copy_map (
	id		BIGSERIAL	PRIMARY KEY,
	stat_cat	INT		NOT NULL,
	stat_cat_entry	INT		NOT NULL,
	owning_copy	BIGINT		NOT NULL,
	CONSTRAINT sce_once_per_copy UNIQUE (owning_copy,stat_cat)
);
CREATE INDEX scecm_owning_copy_idx ON asset.stat_cat_entry_copy_map(owning_copy);

CREATE TABLE asset.copy_note (
	id		BIGSERIAL			PRIMARY KEY,
	owning_copy	BIGINT				NOT NULL,
	creator		BIGINT				NOT NULL,
	create_date	TIMESTAMP WITH TIME ZONE	DEFAULT NOW(),
	pub		BOOL				NOT NULL DEFAULT FALSE,
	title		TEXT				NOT NULL,
	value		TEXT				NOT NULL
);
CREATE INDEX asset_copy_note_creator_idx ON asset.copy_note ( creator );
CREATE INDEX asset_copy_note_owning_copy_idx ON asset.copy_note ( owning_copy );

CREATE TABLE asset.uri (
    id  SERIAL  PRIMARY KEY,
    href    TEXT    NOT NULL,
    label   TEXT,
    use_restriction TEXT,
    active  BOOL    NOT NULL DEFAULT TRUE
);

CREATE TABLE asset.call_number_class (
    id             bigserial     PRIMARY KEY,
    name           TEXT          NOT NULL,
    normalizer     TEXT          NOT NULL DEFAULT 'asset.normalize_generic',
    field          TEXT          NOT NULL DEFAULT '050ab,055ab,060ab,070ab,080ab,082ab,086ab,088ab,090,092,096,098,099'
);
COMMENT ON TABLE asset.call_number_class IS $$
Defines the call number normalization database functions in the "normalizer"
column and the tag/subfield combinations to use to lookup the call number in
the "field" column for a given classification scheme. Tag/subfield combinations
are delimited by commas.
$$;

CREATE OR REPLACE FUNCTION asset.label_normalizer() RETURNS TRIGGER AS $func$
DECLARE
    sortkey        TEXT := '';
BEGIN
    sortkey := NEW.label_sortkey;

    EXECUTE 'SELECT ' || acnc.normalizer || '(' || 
       quote_literal( NEW.label ) || ')'
       FROM asset.call_number_class acnc
       WHERE acnc.id = NEW.label_class
       INTO sortkey;

    NEW.label_sortkey = sortkey;

    RETURN NEW;
END;
$func$ LANGUAGE PLPGSQL;

CREATE OR REPLACE FUNCTION asset.label_normalizer_generic(TEXT) RETURNS TEXT AS $func$
    # Created after looking at the Koha C4::ClassSortRoutine::Generic module,
    # thus could probably be considered a derived work, although nothing was
    # directly copied - but to err on the safe side of providing attribution:
    # Copyright (C) 2007 LibLime
    # Licensed under the GPL v2 or later

    use strict;
    use warnings;

    # Converts the callnumber to uppercase
    # Strips spaces from start and end of the call number
    # Converts anything other than letters, digits, and periods into underscores
    # Collapses multiple underscores into a single underscore
    my $callnum = uc(shift);
    $callnum =~ s/^\s//g;
    $callnum =~ s/\s$//g;
    $callnum =~ s/[^A-Z0-9_.]/_/g;
    $callnum =~ s/_{2,}/_/g;

    return $callnum;
$func$ LANGUAGE PLPERLU;

CREATE OR REPLACE FUNCTION asset.label_normalizer_dewey(TEXT) RETURNS TEXT AS $func$
    # Derived from the Koha C4::ClassSortRoutine::Dewey module
    # Copyright (C) 2007 LibLime
    # Licensed under the GPL v2 or later

    use strict;
    use warnings;

    my $init = uc(shift);
    $init =~ s/^\s+//;
    $init =~ s/\s+$//;
    $init =~ s!/!!g;
    $init =~ s/^([\p{IsAlpha}]+)/$1 /;
    my @tokens = split /\.|\s+/, $init;
    my $digit_group_count = 0;
    for (my $i = 0; $i <= $#tokens; $i++) {
        if ($tokens[$i] =~ /^\d+$/) {
            $digit_group_count++;
            if (2 == $digit_group_count) {
                $tokens[$i] = sprintf("%-15.15s", $tokens[$i]);
                $tokens[$i] =~ tr/ /0/;
            }
        }
    }
    my $key = join("_", @tokens);
    $key =~ s/[^\p{IsAlnum}_]//g;

    return $key;

$func$ LANGUAGE PLPERLU;

CREATE OR REPLACE FUNCTION asset.label_normalizer_lc(TEXT) RETURNS TEXT AS $func$
    use strict;
    use warnings;

    # Library::CallNumber::LC is currently hosted at http://code.google.com/p/library-callnumber-lc/
    # The author hopes to upload it to CPAN some day, which would make our lives easier
    use Library::CallNumber::LC;

    my $callnum = Library::CallNumber::LC->new(shift);
    return $callnum->normalize();

$func$ LANGUAGE PLPERLU;

INSERT INTO asset.call_number_class (name, normalizer, field) VALUES 
    ('Generic', 'asset.label_normalizer_generic', '050ab,055ab,060ab,070ab,080ab,082ab,086ab,088ab,090,092,096,098,099'),
    ('Dewey (DDC)', 'asset.label_normalizer_dewey', '080ab,082ab'),
    ('Library of Congress (LC)', 'asset.label_normalizer_lc', '050ab,055ab')
;

CREATE TABLE asset.call_number (
	id		bigserial PRIMARY KEY,
	creator		BIGINT				NOT NULL,
	create_date	TIMESTAMP WITH TIME ZONE	DEFAULT NOW(),
	editor		BIGINT				NOT NULL,
	edit_date	TIMESTAMP WITH TIME ZONE	DEFAULT NOW(),
	record		bigint				NOT NULL,
	owning_lib	INT				NOT NULL,
	label		TEXT				NOT NULL,
	deleted		BOOL				NOT NULL DEFAULT FALSE,
	label_class	BIGINT				DEFAULT 1 NOT NULL
							REFERENCES asset.call_number_class(id)
							DEFERRABLE INITIALLY DEFERRED,
	label_sortkey	TEXT
);
CREATE INDEX asset_call_number_record_idx ON asset.call_number (record);
CREATE INDEX asset_call_number_creator_idx ON asset.call_number (creator);
CREATE INDEX asset_call_number_editor_idx ON asset.call_number (editor);
CREATE INDEX asset_call_number_dewey_idx ON asset.call_number (public.call_number_dewey(label));
CREATE INDEX asset_call_number_upper_label_id_owning_lib_idx ON asset.call_number (upper(label),id,owning_lib);
CREATE INDEX asset_call_number_label_sortkey ON asset.call_number(label_sortkey);
CREATE UNIQUE INDEX asset_call_number_label_once_per_lib ON asset.call_number (record, owning_lib, label) WHERE deleted = FALSE OR deleted IS FALSE;
CREATE RULE protect_cn_delete AS ON DELETE TO asset.call_number DO INSTEAD UPDATE asset.call_number SET deleted = TRUE WHERE OLD.id = asset.call_number.id;
CREATE TRIGGER asset_label_sortkey_trigger
    BEFORE UPDATE OR INSERT ON asset.call_number
    FOR EACH ROW EXECUTE PROCEDURE asset.label_normalizer();

CREATE TABLE asset.uri_call_number_map (
    id          BIGSERIAL   PRIMARY KEY,
    uri         INT         NOT NULL REFERENCES asset.uri (id),
    call_number INT         NOT NULL REFERENCES asset.call_number (id),
    CONSTRAINT uri_cn_once UNIQUE (uri,call_number)
);
CREATE INDEX asset_uri_call_number_map_cn_idx ON asset.uri_call_number_map (call_number);

CREATE TABLE asset.call_number_note (
	id		BIGSERIAL			PRIMARY KEY,
	call_number	BIGINT				NOT NULL,
	creator		BIGINT				NOT NULL,
	create_date	TIMESTAMP WITH TIME ZONE	DEFAULT NOW(),
	pub		BOOL				NOT NULL DEFAULT FALSE,
	title		TEXT				NOT NULL,
	value		TEXT				NOT NULL
);
CREATE INDEX asset_call_number_note_creator_idx ON asset.call_number_note ( creator );

CREATE TABLE asset.copy_template (
	id             SERIAL   PRIMARY KEY,
	owning_lib     INT      NOT NULL
	                        REFERENCES actor.org_unit (id)
	                        DEFERRABLE INITIALLY DEFERRED,
	creator        BIGINT   NOT NULL
	                        REFERENCES actor.usr (id)
	                        DEFERRABLE INITIALLY DEFERRED,
	editor         BIGINT   NOT NULL
	                        REFERENCES actor.usr (id)
	                        DEFERRABLE INITIALLY DEFERRED,
	create_date    TIMESTAMP WITH TIME ZONE    DEFAULT NOW(),
	edit_date      TIMESTAMP WITH TIME ZONE    DEFAULT NOW(),
	name           TEXT     NOT NULL,
	-- columns above this point are attributes of the template itself
	-- columns after this point are attributes of the copy this template modifies/creates
	circ_lib       INT      REFERENCES actor.org_unit (id)
	                        DEFERRABLE INITIALLY DEFERRED,
	status         INT      REFERENCES config.copy_status (id)
	                        DEFERRABLE INITIALLY DEFERRED,
	location       INT      REFERENCES asset.copy_location (id)
	                        DEFERRABLE INITIALLY DEFERRED,
	loan_duration  INT      CONSTRAINT valid_loan_duration CHECK (
	                            loan_duration IS NULL OR loan_duration IN (1,2,3)),
	fine_level     INT      CONSTRAINT valid_fine_level CHECK (
	                            fine_level IS NULL OR loan_duration IN (1,2,3)),
	age_protect    INT,
	circulate      BOOL,
	deposit        BOOL,
	ref            BOOL,
	holdable       BOOL,
	deposit_amount NUMERIC(6,2),
	price          NUMERIC(8,2),
	circ_modifier  TEXT,
	circ_as_type   TEXT,
	alert_message  TEXT,
	opac_visible   BOOL,
	floating       BOOL,
	mint_condition BOOL
);

CREATE VIEW stats.fleshed_copy AS 
        SELECT  cp.*,
		CAST(cp.create_date AS DATE) AS create_date_day,
		CAST(cp.edit_date AS DATE) AS edit_date_day,
		DATE_TRUNC('hour', cp.create_date) AS create_date_hour,
		DATE_TRUNC('hour', cp.edit_date) AS edit_date_hour,
                cn.label AS call_number_label,
                cn.owning_lib,
                rd.item_lang,
                rd.item_type,
                rd.item_form
        FROM    asset.copy cp
                JOIN asset.call_number cn ON (cp.call_number = cn.id)
                JOIN metabib.rec_descriptor rd ON (rd.record = cn.record);

CREATE VIEW stats.fleshed_call_number AS 
        SELECT  cn.*,
       		CAST(cn.create_date AS DATE) AS create_date_day,
		CAST(cn.edit_date AS DATE) AS edit_date_day,
		DATE_TRUNC('hour', cn.create_date) AS create_date_hour,
		DATE_TRUNC('hour', cn.edit_date) AS edit_date_hour,
         	rd.item_lang,
                rd.item_type,
                rd.item_form
        FROM    asset.call_number cn
                JOIN metabib.rec_descriptor rd ON (rd.record = cn.record);

CREATE OR REPLACE FUNCTION asset.opac_ou_record_copy_count (org INT, record BIGINT) RETURNS TABLE (depth INT, org_unit INT, visible BIGINT, available BIGINT, unshadow BIGINT, transcendant INT) AS $f$
DECLARE
    ans RECORD;
    trans INT;
BEGIN
    SELECT 1 INTO trans FROM biblio.record_entry b JOIN config.bib_source src ON (b.source = src.id) WHERE src.transcendant AND b.id = record;

    FOR ans IN SELECT u.id, t.depth FROM actor.org_unit_ancestors(org) AS u JOIN actor.org_unit_type t ON (u.ou_type = t.id) LOOP
        RETURN QUERY
        SELECT  ans.depth,
                ans.id,
                COUNT( av.id ),
                SUM( CASE WHEN cp.status IN (0,7,12) THEN 1 ELSE 0 END ),
                COUNT( av.id ),
                trans
          FROM  
                actor.org_unit_descendants(ans.id) d
                JOIN asset.opac_visible_copies av ON (av.record = record AND av.circ_lib = d.id)
                JOIN asset.copy cp ON (cp.id = av.id)
          GROUP BY 1,2,6;

        IF NOT FOUND THEN
            RETURN QUERY SELECT ans.depth, ans.id, 0::BIGINT, 0::BIGINT, 0::BIGINT, trans;
        END IF;

    END LOOP;

    RETURN;
END;
$f$ LANGUAGE PLPGSQL;

CREATE OR REPLACE FUNCTION asset.opac_lasso_record_copy_count (i_lasso INT, record BIGINT) RETURNS TABLE (depth INT, org_unit INT, visible BIGINT, available BIGINT, unshadow BIGINT, transcendant INT) AS $f$
DECLARE
    ans RECORD;
    trans INT;
BEGIN
    SELECT 1 INTO trans FROM biblio.record_entry b JOIN config.bib_source src ON (b.source = src.id) WHERE src.transcendant AND b.id = record;

    FOR ans IN SELECT u.org_unit AS id FROM actor.org_lasso_map AS u WHERE lasso = i_lasso LOOP
        RETURN QUERY
        SELECT  -1,
                ans.id,
                COUNT( av.id ),
                SUM( CASE WHEN cp.status IN (0,7,12) THEN 1 ELSE 0 END ),
                COUNT( av.id ),
                trans
          FROM
                actor.org_unit_descendants(ans.id) d
                JOIN asset.opac_visible_copies av ON (av.record = record AND av.circ_lib = d.id)
                JOIN asset.copy cp ON (cp.id = av.id)
          GROUP BY 1,2,6;

        IF NOT FOUND THEN
            RETURN QUERY SELECT ans.depth, ans.id, 0::BIGINT, 0::BIGINT, 0::BIGINT, trans;
        END IF;

    END LOOP;   
                
    RETURN;     
END;            
$f$ LANGUAGE PLPGSQL;

CREATE OR REPLACE FUNCTION asset.staff_ou_record_copy_count (org INT, record BIGINT) RETURNS TABLE (depth INT, org_unit INT, visible BIGINT, available BIGINT, unshadow BIGINT, transcendant INT) AS $f$
DECLARE         
    ans RECORD; 
    trans INT;
BEGIN           
    SELECT 1 INTO trans FROM biblio.record_entry b JOIN config.bib_source src ON (b.source = src.id) WHERE src.transcendant AND b.id = record;

    FOR ans IN SELECT u.id, t.depth FROM actor.org_unit_ancestors(org) AS u JOIN actor.org_unit_type t ON (u.ou_type = t.id) LOOP
        RETURN QUERY
        SELECT  ans.depth,
                ans.id,
                COUNT( cp.id ),
                SUM( CASE WHEN cp.status IN (0,7,12) THEN 1 ELSE 0 END ),
                COUNT( cp.id ),
                trans
          FROM
                actor.org_unit_descendants(ans.id) d
                JOIN asset.copy cp ON (cp.circ_lib = d.id)
                JOIN asset.call_number cn ON (cn.record = record AND cn.id = cp.call_number)
          GROUP BY 1,2,6;

        IF NOT FOUND THEN
            RETURN QUERY SELECT ans.depth, ans.id, 0::BIGINT, 0::BIGINT, 0::BIGINT, trans;
        END IF;

    END LOOP;

    RETURN;
END;
$f$ LANGUAGE PLPGSQL;

CREATE OR REPLACE FUNCTION asset.staff_lasso_record_copy_count (i_lasso INT, record BIGINT) RETURNS TABLE (depth INT, org_unit INT, visible BIGINT, available BIGINT, unshadow BIGINT, transcendant INT) AS $f$
DECLARE
    ans RECORD;
    trans INT;
BEGIN
    SELECT 1 INTO trans FROM biblio.record_entry b JOIN config.bib_source src ON (b.source = src.id) WHERE src.transcendant AND b.id = record;

    FOR ans IN SELECT u.org_unit AS id FROM actor.org_lasso_map AS u WHERE lasso = i_lasso LOOP
        RETURN QUERY
        SELECT  -1,
                ans.id,
                COUNT( cp.id ),
                SUM( CASE WHEN cp.status IN (0,7,12) THEN 1 ELSE 0 END ),
                COUNT( cp.id ),
                trans
          FROM
                actor.org_unit_descendants(ans.id) d
                JOIN asset.copy cp ON (cp.circ_lib = d.id)
                JOIN asset.call_number cn ON (cn.record = record AND cn.id = cp.call_number)
          GROUP BY 1,2,6;

        IF NOT FOUND THEN
            RETURN QUERY SELECT ans.depth, ans.id, 0::BIGINT, 0::BIGINT, 0::BIGINT, trans;
        END IF;

    END LOOP;

    RETURN;
END;
$f$ LANGUAGE PLPGSQL;

CREATE OR REPLACE FUNCTION asset.record_copy_count ( place INT, record BIGINT, staff BOOL) RETURNS TABLE (depth INT, org_unit INT, visible BIGINT, available BIGINT, unshadow BIGINT, transcendant INT) AS $f$
BEGIN
    IF staff IS TRUE THEN
        IF place > 0 THEN
            RETURN QUERY SELECT * FROM asset.staff_ou_record_copy_count( place, record );
        ELSE
            RETURN QUERY SELECT * FROM asset.staff_lasso_record_copy_count( -place, record );
        END IF;
    ELSE
        IF place > 0 THEN
            RETURN QUERY SELECT * FROM asset.opac_ou_record_copy_count( place, record );
        ELSE
            RETURN QUERY SELECT * FROM asset.opac_lasso_record_copy_count( -place, record );
        END IF;
    END IF;

    RETURN;
END;
$f$ LANGUAGE PLPGSQL;

CREATE OR REPLACE FUNCTION asset.opac_ou_metarecord_copy_count (org INT, record BIGINT) RETURNS TABLE (depth INT, org_unit INT, visible BIGINT, available BIGINT, unshadow BIGINT, transcendant INT) AS $f$
DECLARE
    ans RECORD;
    trans INT;
BEGIN
    SELECT 1 INTO trans FROM biblio.record_entry b JOIN config.bib_source src ON (b.source = src.id) WHERE src.transcendant AND b.id = record;

    FOR ans IN SELECT u.id, t.depth FROM actor.org_unit_ancestors(org) AS u JOIN actor.org_unit_type t ON (u.ou_type = t.id) LOOP
        RETURN QUERY
        SELECT  ans.depth,
                ans.id,
                COUNT( av.id ),
                SUM( CASE WHEN cp.status IN (0,7,12) THEN 1 ELSE 0 END ),
                COUNT( av.id ),
                trans
          FROM  
                actor.org_unit_descendants(ans.id) d
                JOIN asset.opac_visible_copies av ON (av.record = record AND av.circ_lib = d.id)
                JOIN asset.copy cp ON (cp.id = av.id)
                JOIN metabib.metarecord_source_map m ON (m.source = av.record)
          GROUP BY 1,2,6;

        IF NOT FOUND THEN
            RETURN QUERY SELECT ans.depth, ans.id, 0::BIGINT, 0::BIGINT, 0::BIGINT, trans;
        END IF;

    END LOOP;

    RETURN;
END;
$f$ LANGUAGE PLPGSQL;

CREATE OR REPLACE FUNCTION asset.opac_lasso_metarecord_copy_count (i_lasso INT, record BIGINT) RETURNS TABLE (depth INT, org_unit INT, visible BIGINT, available BIGINT, unshadow BIGINT, transcendant INT) AS $f$
DECLARE
    ans RECORD;
    trans INT;
BEGIN
    SELECT 1 INTO trans FROM biblio.record_entry b JOIN config.bib_source src ON (b.source = src.id) WHERE src.transcendant AND b.id = record;

    FOR ans IN SELECT u.org_unit AS id FROM actor.org_lasso_map AS u WHERE lasso = i_lasso LOOP
        RETURN QUERY
        SELECT  -1,
                ans.id,
                COUNT( av.id ),
                SUM( CASE WHEN cp.status IN (0,7,12) THEN 1 ELSE 0 END ),
                COUNT( av.id ),
                trans
          FROM
                actor.org_unit_descendants(ans.id) d
                JOIN asset.opac_visible_copies av ON (av.record = record AND av.circ_lib = d.id)
                JOIN asset.copy cp ON (cp.id = av.id)
                JOIN metabib.metarecord_source_map m ON (m.source = av.record)
          GROUP BY 1,2,6;

        IF NOT FOUND THEN
            RETURN QUERY SELECT ans.depth, ans.id, 0::BIGINT, 0::BIGINT, 0::BIGINT, trans;
        END IF;

    END LOOP;   
                
    RETURN;     
END;            
$f$ LANGUAGE PLPGSQL;

CREATE OR REPLACE FUNCTION asset.staff_ou_metarecord_copy_count (org INT, record BIGINT) RETURNS TABLE (depth INT, org_unit INT, visible BIGINT, available BIGINT, unshadow BIGINT, transcendant INT) AS $f$
DECLARE         
    ans RECORD; 
    trans INT;
BEGIN
    SELECT 1 INTO trans FROM biblio.record_entry b JOIN config.bib_source src ON (b.source = src.id) WHERE src.transcendant AND b.id = record;

    FOR ans IN SELECT u.id, t.depth FROM actor.org_unit_ancestors(org) AS u JOIN actor.org_unit_type t ON (u.ou_type = t.id) LOOP
        RETURN QUERY
        SELECT  ans.depth,
                ans.id,
                COUNT( cp.id ),
                SUM( CASE WHEN cp.status IN (0,7,12) THEN 1 ELSE 0 END ),
                COUNT( cp.id ),
                trans
          FROM
                actor.org_unit_descendants(ans.id) d
                JOIN asset.copy cp ON (cp.circ_lib = d.id)
                JOIN asset.call_number cn ON (cn.record = record AND cn.id = cp.call_number)
                JOIN metabib.metarecord_source_map m ON (m.source = cn.record)
          GROUP BY 1,2,6;

        IF NOT FOUND THEN
            RETURN QUERY SELECT ans.depth, ans.id, 0::BIGINT, 0::BIGINT, 0::BIGINT, trans;
        END IF;

    END LOOP;

    RETURN;
END;
$f$ LANGUAGE PLPGSQL;

CREATE OR REPLACE FUNCTION asset.staff_lasso_metarecord_copy_count (i_lasso INT, record BIGINT) RETURNS TABLE (depth INT, org_unit INT, visible BIGINT, available BIGINT, unshadow BIGINT, transcendant INT) AS $f$
DECLARE
    ans RECORD;
    trans INT;
BEGIN
    SELECT 1 INTO trans FROM biblio.record_entry b JOIN config.bib_source src ON (b.source = src.id) WHERE src.transcendant AND b.id = record;

    FOR ans IN SELECT u.org_unit AS id FROM actor.org_lasso_map AS u WHERE lasso = i_lasso LOOP
        RETURN QUERY
        SELECT  -1,
                ans.id,
                COUNT( cp.id ),
                SUM( CASE WHEN cp.status IN (0,7,12) THEN 1 ELSE 0 END ),
                COUNT( cp.id ),
                trans
          FROM
                actor.org_unit_descendants(ans.id) d
                JOIN asset.copy cp ON (cp.circ_lib = d.id)
                JOIN asset.call_number cn ON (cn.record = record AND cn.id = cp.call_number)
                JOIN metabib.metarecord_source_map m ON (m.source = cn.record)
          GROUP BY 1,2,6;

        IF NOT FOUND THEN
            RETURN QUERY SELECT ans.depth, ans.id, 0::BIGINT, 0::BIGINT, 0::BIGINT, trans;
        END IF;

    END LOOP;

    RETURN;
END;
$f$ LANGUAGE PLPGSQL;

CREATE OR REPLACE FUNCTION asset.metarecord_copy_count ( place INT, record BIGINT, staff BOOL) RETURNS TABLE (depth INT, org_unit INT, visible BIGINT, available BIGINT, unshadow BIGINT, transcendant INT) AS $f$
BEGIN
    IF staff IS TRUE THEN
        IF place > 0 THEN
            RETURN QUERY SELECT * FROM asset.staff_ou_metarecord_copy_count( place, record );
        ELSE
            RETURN QUERY SELECT * FROM asset.staff_lasso_metarecord_copy_count( -place, record );
        END IF;
    ELSE
        IF place > 0 THEN
            RETURN QUERY SELECT * FROM asset.opac_ou_metarecord_copy_count( place, record );
        ELSE
            RETURN QUERY SELECT * FROM asset.opac_lasso_metarecord_copy_count( -place, record );
        END IF;
    END IF;

    RETURN;
END;
$f$ LANGUAGE PLPGSQL;

COMMIT;

