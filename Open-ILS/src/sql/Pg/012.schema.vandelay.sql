DROP SCHEMA IF EXISTS vandelay CASCADE;

BEGIN;

CREATE SCHEMA vandelay;

CREATE TABLE vandelay.queue (
	id				BIGSERIAL	PRIMARY KEY,
	owner			INT			NOT NULL REFERENCES actor.usr (id) DEFERRABLE INITIALLY DEFERRED,
	name			TEXT		NOT NULL,
	complete		BOOL		NOT NULL DEFAULT FALSE,
	queue_type		TEXT		NOT NULL DEFAULT 'bib' CHECK (queue_type IN ('bib','authority')),
	CONSTRAINT vand_queue_name_once_per_owner_const UNIQUE (owner,name,queue_type)
);

CREATE TABLE vandelay.queued_record (
    id			BIGSERIAL                   PRIMARY KEY,
    create_time	TIMESTAMP WITH TIME ZONE    NOT NULL DEFAULT NOW(),
    import_time	TIMESTAMP WITH TIME ZONE,
	purpose		TEXT						NOT NULL DEFAULT 'import' CHECK (purpose IN ('import','overlay')),
    marc		TEXT                        NOT NULL
);



/* Bib stuff at the top */
----------------------------------------------------

CREATE TABLE vandelay.bib_attr_definition (
	id			SERIAL	PRIMARY KEY,
	code		TEXT	UNIQUE NOT NULL,
	description	TEXT,
	xpath		TEXT	NOT NULL,
	remove		TEXT	NOT NULL DEFAULT '',
	ident		BOOL	NOT NULL DEFAULT FALSE
);

-- Each TEXT field (other than 'name') should hold an XPath predicate for pulling the data needed
-- DROP TABLE vandelay.import_item_attr_definition CASCADE;
CREATE TABLE vandelay.import_item_attr_definition (
    id              BIGSERIAL   PRIMARY KEY,
    owner           INT         NOT NULL REFERENCES actor.org_unit (id) ON UPDATE CASCADE ON DELETE CASCADE DEFERRABLE INITIALLY DEFERRED,
    name            TEXT        NOT NULL,
    tag             TEXT        NOT NULL,
    keep            BOOL        NOT NULL DEFAULT FALSE,
    owning_lib      TEXT,
    circ_lib        TEXT,
    call_number     TEXT,
    copy_number     TEXT,
    status          TEXT,
    location        TEXT,
    circulate       TEXT,
    deposit         TEXT,
    deposit_amount  TEXT,
    ref             TEXT,
    holdable        TEXT,
    price           TEXT,
    barcode         TEXT,
    circ_modifier   TEXT,
    circ_as_type    TEXT,
    alert_message   TEXT,
    opac_visible    TEXT,
    pub_note_title  TEXT,
    pub_note        TEXT,
    priv_note_title TEXT,
    priv_note       TEXT,
	CONSTRAINT vand_import_item_attr_def_idx UNIQUE (owner,name)
);

CREATE TABLE vandelay.bib_queue (
	queue_type	    TEXT	NOT NULL DEFAULT 'bib' CHECK (queue_type = 'bib'),
	item_attr_def	BIGINT REFERENCES vandelay.import_item_attr_definition (id) ON DELETE SET NULL DEFERRABLE INITIALLY DEFERRED,
	CONSTRAINT vand_bib_queue_name_once_per_owner_const UNIQUE (owner,name,queue_type)
) INHERITS (vandelay.queue);
ALTER TABLE vandelay.bib_queue ADD PRIMARY KEY (id);

CREATE TABLE vandelay.queued_bib_record (
	queue		INT		NOT NULL REFERENCES vandelay.bib_queue (id) ON DELETE CASCADE DEFERRABLE INITIALLY DEFERRED,
	bib_source	INT		REFERENCES config.bib_source (id) DEFERRABLE INITIALLY DEFERRED,
	imported_as	BIGINT	REFERENCES biblio.record_entry (id) DEFERRABLE INITIALLY DEFERRED
) INHERITS (vandelay.queued_record);
ALTER TABLE vandelay.queued_bib_record ADD PRIMARY KEY (id);
CREATE INDEX queued_bib_record_queue_idx ON vandelay.queued_bib_record (queue);

CREATE TABLE vandelay.queued_bib_record_attr (
	id			BIGSERIAL	PRIMARY KEY,
	record		BIGINT		NOT NULL REFERENCES vandelay.queued_bib_record (id) DEFERRABLE INITIALLY DEFERRED,
	field		INT			NOT NULL REFERENCES vandelay.bib_attr_definition (id) DEFERRABLE INITIALLY DEFERRED,
	attr_value	TEXT		NOT NULL
);
CREATE INDEX queued_bib_record_attr_record_idx ON vandelay.queued_bib_record_attr (record);

CREATE TABLE vandelay.bib_match (
	id				BIGSERIAL	PRIMARY KEY,
	field_type		TEXT		NOT NULL CHECK (field_type in ('isbn','tcn_value','id')),
	matched_attr	INT			REFERENCES vandelay.queued_bib_record_attr (id) ON DELETE CASCADE DEFERRABLE INITIALLY DEFERRED,
	queued_record	BIGINT		REFERENCES vandelay.queued_bib_record (id) ON DELETE CASCADE DEFERRABLE INITIALLY DEFERRED,
	eg_record		BIGINT		REFERENCES biblio.record_entry (id) ON DELETE CASCADE DEFERRABLE INITIALLY DEFERRED
);

-- DROP TABLE vandelay.import_item CASCADE;
CREATE TABLE vandelay.import_item (
    id              BIGSERIAL   PRIMARY KEY,
    record          BIGINT      NOT NULL REFERENCES vandelay.queued_bib_record (id) ON DELETE CASCADE DEFERRABLE INITIALLY DEFERRED,
    definition      BIGINT      NOT NULL REFERENCES vandelay.import_item_attr_definition (id) ON DELETE CASCADE DEFERRABLE INITIALLY DEFERRED,
    owning_lib      INT,
    circ_lib        INT,
    call_number     TEXT,
    copy_number     INT,
    status          INT,
    location        INT,
    circulate       BOOL,
    deposit         BOOL,
    deposit_amount  NUMERIC(8,2),
    ref             BOOL,
    holdable        BOOL,
    price           NUMERIC(8,2),
    barcode         TEXT,
    circ_modifier   TEXT,
    circ_as_type    TEXT,
    alert_message   TEXT,
    pub_note        TEXT,
    priv_note       TEXT,
    opac_visible    BOOL
);
 
CREATE TABLE vandelay.import_bib_trash_fields (
    id              BIGSERIAL   PRIMARY KEY,
    owner           INT         NOT NULL REFERENCES actor.org_unit (id) ON UPDATE CASCADE ON DELETE CASCADE DEFERRABLE INITIALLY DEFERRED,
    field           TEXT        NOT NULL,
	CONSTRAINT vand_import_bib_trash_fields_idx UNIQUE (owner,field)
);

CREATE TABLE vandelay.merge_profile (
    id              BIGSERIAL   PRIMARY KEY,
    owner           INT         NOT NULL REFERENCES actor.org_unit (id) ON UPDATE CASCADE ON DELETE CASCADE DEFERRABLE INITIALLY DEFERRED,
    name            TEXT        NOT NULL,
    add_spec        TEXT,
    replace_spec    TEXT,
    strip_spec      TEXT,
    preserve_spec   TEXT,
	CONSTRAINT vand_merge_prof_owner_name_idx UNIQUE (owner,name),
	CONSTRAINT add_replace_strip_or_preserve CHECK ((preserve_spec IS NOT NULL OR replace_spec IS NOT NULL) OR (preserve_spec IS NULL AND replace_spec IS NULL))
);


CREATE TYPE vandelay.tcn_data AS (tcn TEXT, tcn_source TEXT, used BOOL);
CREATE OR REPLACE FUNCTION vandelay.find_bib_tcn_data ( xml TEXT ) RETURNS SETOF vandelay.tcn_data AS $_$
DECLARE
    eg_tcn          TEXT;
    eg_tcn_source   TEXT;
    output          vandelay.tcn_data%ROWTYPE;
BEGIN

    -- 001/003
    eg_tcn := BTRIM((oils_xpath('//*[@tag="001"]/text()',xml))[1]);
    IF eg_tcn IS NOT NULL AND eg_tcn <> '' THEN

        eg_tcn_source := BTRIM((oils_xpath('//*[@tag="003"]/text()',xml))[1]);
        IF eg_tcn_source IS NULL OR eg_tcn_source = '' THEN
            eg_tcn_source := 'System Local';
        END IF;

        PERFORM id FROM biblio.record_entry WHERE tcn_value = eg_tcn  AND NOT deleted;

        IF NOT FOUND THEN
            output.used := FALSE;
        ELSE
            output.used := TRUE;
        END IF;

        output.tcn := eg_tcn;
        output.tcn_source := eg_tcn_source;
        RETURN NEXT output;

    END IF;

    -- 901 ab
    eg_tcn := BTRIM((oils_xpath('//*[@tag="901"]/*[@code="a"]/text()',xml))[1]);
    IF eg_tcn IS NOT NULL AND eg_tcn <> '' THEN

        eg_tcn_source := BTRIM((oils_xpath('//*[@tag="901"]/*[@code="b"]/text()',xml))[1]);
        IF eg_tcn_source IS NULL OR eg_tcn_source = '' THEN
            eg_tcn_source := 'System Local';
        END IF;

        PERFORM id FROM biblio.record_entry WHERE tcn_value = eg_tcn  AND NOT deleted;

        IF NOT FOUND THEN
            output.used := FALSE;
        ELSE
            output.used := TRUE;
        END IF;

        output.tcn := eg_tcn;
        output.tcn_source := eg_tcn_source;
        RETURN NEXT output;

    END IF;

    -- 039 ab
    eg_tcn := BTRIM((oils_xpath('//*[@tag="039"]/*[@code="a"]/text()',xml))[1]);
    IF eg_tcn IS NOT NULL AND eg_tcn <> '' THEN

        eg_tcn_source := BTRIM((oils_xpath('//*[@tag="039"]/*[@code="b"]/text()',xml))[1]);
        IF eg_tcn_source IS NULL OR eg_tcn_source = '' THEN
            eg_tcn_source := 'System Local';
        END IF;

        PERFORM id FROM biblio.record_entry WHERE tcn_value = eg_tcn  AND NOT deleted;

        IF NOT FOUND THEN
            output.used := FALSE;
        ELSE
            output.used := TRUE;
        END IF;

        output.tcn := eg_tcn;
        output.tcn_source := eg_tcn_source;
        RETURN NEXT output;

    END IF;

    -- 020 a
    eg_tcn := REGEXP_REPLACE((oils_xpath('//*[@tag="020"]/*[@code="a"]/text()',xml))[1], $re$^(\w+).*?$$re$, $re$\1$re$);
    IF eg_tcn IS NOT NULL AND eg_tcn <> '' THEN

        eg_tcn_source := 'ISBN';

        PERFORM id FROM biblio.record_entry WHERE tcn_value = eg_tcn  AND NOT deleted;

        IF NOT FOUND THEN
            output.used := FALSE;
        ELSE
            output.used := TRUE;
        END IF;

        output.tcn := eg_tcn;
        output.tcn_source := eg_tcn_source;
        RETURN NEXT output;

    END IF;

    -- 022 a
    eg_tcn := REGEXP_REPLACE((oils_xpath('//*[@tag="022"]/*[@code="a"]/text()',xml))[1], $re$^(\w+).*?$$re$, $re$\1$re$);
    IF eg_tcn IS NOT NULL AND eg_tcn <> '' THEN

        eg_tcn_source := 'ISSN';

        PERFORM id FROM biblio.record_entry WHERE tcn_value = eg_tcn  AND NOT deleted;

        IF NOT FOUND THEN
            output.used := FALSE;
        ELSE
            output.used := TRUE;
        END IF;

        output.tcn := eg_tcn;
        output.tcn_source := eg_tcn_source;
        RETURN NEXT output;

    END IF;

    -- 010 a
    eg_tcn := REGEXP_REPLACE((oils_xpath('//*[@tag="010"]/*[@code="a"]/text()',xml))[1], $re$^(\w+).*?$$re$, $re$\1$re$);
    IF eg_tcn IS NOT NULL AND eg_tcn <> '' THEN

        eg_tcn_source := 'LCCN';

        PERFORM id FROM biblio.record_entry WHERE tcn_value = eg_tcn  AND NOT deleted;

        IF NOT FOUND THEN
            output.used := FALSE;
        ELSE
            output.used := TRUE;
        END IF;

        output.tcn := eg_tcn;
        output.tcn_source := eg_tcn_source;
        RETURN NEXT output;

    END IF;

    -- 035 a
    eg_tcn := REGEXP_REPLACE((oils_xpath('//*[@tag="035"]/*[@code="a"]/text()',xml))[1], $re$^.*?(\w+)$$re$, $re$\1$re$);
    IF eg_tcn IS NOT NULL AND eg_tcn <> '' THEN

        eg_tcn_source := 'System Legacy';

        PERFORM id FROM biblio.record_entry WHERE tcn_value = eg_tcn  AND NOT deleted;

        IF NOT FOUND THEN
            output.used := FALSE;
        ELSE
            output.used := TRUE;
        END IF;

        output.tcn := eg_tcn;
        output.tcn_source := eg_tcn_source;
        RETURN NEXT output;

    END IF;

    RETURN;
END;
$_$ LANGUAGE PLPGSQL;

CREATE OR REPLACE FUNCTION vandelay.add_field ( target_xml TEXT, source_xml TEXT, field TEXT ) RETURNS TEXT AS $_$

    use MARC::Record;
    use MARC::File::XML (BinaryEncoding => 'UTF-8');
    use strict;

    my $target_xml = shift;
    my $source_xml = shift;
    my $field_spec = shift;

    my $target_r = MARC::Record->new_from_xml( $target_xml );
    my $source_r = MARC::Record->new_from_xml( $source_xml );

    return $target_xml unless ($target_r && $source_r);

    my @field_list = split(',', $field_spec);

    my %fields;
    for my $f (@field_list) {
        $f =~ s/^\s*//; $f =~ s/\s*$//;
        if ($f =~ /^(.{3})(\w*)(?:\[([^]]*)\])?$/) {
            my $field = $1;
            $field =~ s/\s+//;
            my $sf = $2;
            $sf =~ s/\s+//;
            my $match = $3;
            $match =~ s/^\s*//; $match =~ s/\s*$//;
            $fields{$field} = { sf => [ split('', $sf) ] };
            if ($match) {
                my ($msf,$mre) = split('~', $match);
                if (length($msf) > 0 and length($mre) > 0) {
                    $msf =~ s/^\s*//; $msf =~ s/\s*$//;
                    $mre =~ s/^\s*//; $mre =~ s/\s*$//;
                    $fields{$field}{match} = { sf => $msf, re => qr/$mre/ };
                }
            }
        }
    }

    for my $f ( keys %fields) {
        if ( @{$fields{$f}{sf}} ) {
            for my $from_field ($source_r->field( $f )) {
                my @tos = $target_r->field( $f );
                if (!@tos) {
                    my @new_fields = map { $_->clone } $source_r->field( $f );
                    $target_r->insert_fields_ordered( @new_fields );
                } else {
                    for my $to_field (@tos) {
                        if (exists($fields{$f}{match})) {
                            next unless (grep { $_ =~ $fields{$f}{match}{re} } $to_field->subfield($fields{$f}{match}{sf}));
                        }
                        my @new_sf = map { ($_ => $from_field->subfield($_)) } @{$fields{$f}{sf}};
                        $to_field->add_subfields( @new_sf );
                    }
                }
            }
        } else {
            my @new_fields = map { $_->clone } $source_r->field( $f );
            $target_r->insert_fields_ordered( @new_fields );
        }
    }

    $target_xml = $target_r->as_xml_record;
    $target_xml =~ s/^<\?.+?\?>$//mo;
    $target_xml =~ s/\n//sgo;
    $target_xml =~ s/>\s+</></sgo;

    return $target_xml;

$_$ LANGUAGE PLPERLU;

CREATE OR REPLACE FUNCTION vandelay.strip_field ( xml TEXT, field TEXT ) RETURNS TEXT AS $_$

    use MARC::Record;
    use MARC::File::XML (BinaryEncoding => 'UTF-8');
    use strict;

    my $xml = shift;
    my $r = MARC::Record->new_from_xml( $xml );

    return $xml unless ($r);

    my $field_spec = shift;
    my @field_list = split(',', $field_spec);

    my %fields;
    for my $f (@field_list) {
        $f =~ s/^\s*//; $f =~ s/\s*$//;
        if ($f =~ /^(.{3})(\w*)(?:\[([^]]*)\])?$/) {
            my $field = $1;
            $field =~ s/\s+//;
            my $sf = $2;
            $sf =~ s/\s+//;
            my $match = $3;
            $match =~ s/^\s*//; $match =~ s/\s*$//;
            $fields{$field} = { sf => [ split('', $sf) ] };
            if ($match) {
                my ($msf,$mre) = split('~', $match);
                if (length($msf) > 0 and length($mre) > 0) {
                    $msf =~ s/^\s*//; $msf =~ s/\s*$//;
                    $mre =~ s/^\s*//; $mre =~ s/\s*$//;
                    $fields{$field}{match} = { sf => $msf, re => qr/$mre/ };
                }
            }
        }
    }

    for my $f ( keys %fields) {
        for my $to_field ($r->field( $f )) {
            if (exists($fields{$f}{match})) {
                next unless (grep { $_ =~ $fields{$f}{match}{re} } $to_field->subfield($fields{$f}{match}{sf}));
            }

            if ( @{$fields{$f}{sf}} ) {
                $to_field->delete_subfield(code => $fields{$f}{sf});
            } else {
                $r->delete_field( $to_field );
            }
        }
    }

    $xml = $r->as_xml_record;
    $xml =~ s/^<\?.+?\?>$//mo;
    $xml =~ s/\n//sgo;
    $xml =~ s/>\s+</></sgo;

    return $xml;

$_$ LANGUAGE PLPERLU;

CREATE OR REPLACE FUNCTION vandelay.replace_field ( target_xml TEXT, source_xml TEXT, field TEXT ) RETURNS TEXT AS $_$
    SELECT vandelay.add_field( vandelay.strip_field( $1, $3), $2, $3 );
$_$ LANGUAGE SQL;

CREATE OR REPLACE FUNCTION vandelay.merge_record_xml ( target_xml TEXT, source_xml TEXT, add_rule TEXT, replace_preserve_rule TEXT, strip_rule TEXT ) RETURNS TEXT AS $_$
    SELECT vandelay.replace_field( vandelay.add_field( vandelay.strip_field( $1, $5) , $2, $3 ), $2, $4);
$_$ LANGUAGE SQL;

CREATE TYPE vandelay.compile_profile AS (add_rule TEXT, replace_rule TEXT, preserve_rule TEXT, strip_rule TEXT);
CREATE OR REPLACE FUNCTION vandelay.compile_profile ( incoming_xml TEXT ) RETURNS vandelay.compile_profile AS $_$
DECLARE
    output              vandelay.compile_profile%ROWTYPE;
    profile             vandelay.merge_profile%ROWTYPE;
    profile_tmpl        TEXT;
    profile_tmpl_owner  TEXT;
    add_rule            TEXT := '';
    strip_rule          TEXT := '';
    replace_rule        TEXT := '';
    preserve_rule       TEXT := '';

BEGIN

    profile_tmpl := (oils_xpath('//*[@tag="905"]/*[@code="t"]/text()',incoming_xml))[1];
    profile_tmpl_owner := (oils_xpath('//*[@tag="905"]/*[@code="o"]/text()',incoming_xml))[1];

    IF profile_tmpl IS NOT NULL AND profile_tmpl <> '' AND profile_tmpl_owner IS NOT NULL AND profile_tmpl_owner <> '' THEN
        SELECT  p.* INTO profile
          FROM  vandelay.merge_profile p
                JOIN actor.org_unit u ON (u.id = p.owner)
          WHERE p.name = profile_tmpl
                AND u.shortname = profile_tmpl_owner;

        IF profile.id IS NOT NULL THEN
            add_rule := COALESCE(profile.add_spec,'');
            strip_rule := COALESCE(profile.strip_spec,'');
            replace_rule := COALESCE(profile.replace_spec,'');
            preserve_rule := COALESCE(profile.preserve_spec,'');
        END IF;
    END IF;

    add_rule := add_rule || ',' || COALESCE(ARRAY_TO_STRING(oils_xpath('//*[@tag="905"]/*[@code="a"]/text()',incoming_xml),','),'');
    strip_rule := strip_rule || ',' || COALESCE(ARRAY_TO_STRING(oils_xpath('//*[@tag="905"]/*[@code="d"]/text()',incoming_xml),','),'');
    replace_rule := replace_rule || ',' || COALESCE(ARRAY_TO_STRING(oils_xpath('//*[@tag="905"]/*[@code="r"]/text()',incoming_xml),','),'');
    preserve_rule := preserve_rule || ',' || COALESCE(ARRAY_TO_STRING(oils_xpath('//*[@tag="905"]/*[@code="p"]/text()',incoming_xml),','),'');

    output.add_rule := BTRIM(add_rule,',');
    output.replace_rule := BTRIM(replace_rule,',');
    output.strip_rule := BTRIM(strip_rule,',');
    output.preserve_rule := BTRIM(preserve_rule,',');

    RETURN output;
END;
$_$ LANGUAGE PLPGSQL;

CREATE OR REPLACE FUNCTION vandelay.template_overlay_bib_record ( v_marc TEXT, eg_id BIGINT, merge_profile_id INT ) RETURNS BOOL AS $$
DECLARE
    merge_profile   vandelay.merge_profile%ROWTYPE;
    dyn_profile     vandelay.compile_profile%ROWTYPE;
    editor_string   TEXT;
    editor_id       INT;
    source_marc     TEXT;
    target_marc     TEXT;
    eg_marc         TEXT;
    replace_rule    TEXT;
    match_count     INT;
BEGIN

    SELECT  b.marc INTO eg_marc
      FROM  biblio.record_entry b
      WHERE b.id = eg_id
      LIMIT 1;

    IF eg_marc IS NULL OR v_marc IS NULL THEN
        -- RAISE NOTICE 'no marc for template or bib record';
        RETURN FALSE;
    END IF;

    dyn_profile := vandelay.compile_profile( v_marc );

    IF merge_profile_id IS NOT NULL THEN
        SELECT * INTO merge_profile FROM vandelay.merge_profile WHERE id = merge_profile_id;
        IF FOUND THEN
            dyn_profile.add_rule := BTRIM( dyn_profile.add_rule || ',' || COALESCE(merge_profile.add_spec,''), ',');
            dyn_profile.strip_rule := BTRIM( dyn_profile.strip_rule || ',' || COALESCE(merge_profile.strip_spec,''), ',');
            dyn_profile.replace_rule := BTRIM( dyn_profile.replace_rule || ',' || COALESCE(merge_profile.replace_spec,''), ',');
            dyn_profile.preserve_rule := BTRIM( dyn_profile.preserve_rule || ',' || COALESCE(merge_profile.preserve_spec,''), ',');
        END IF;
    END IF;

    IF dyn_profile.replace_rule <> '' AND dyn_profile.preserve_rule <> '' THEN
        -- RAISE NOTICE 'both replace [%] and preserve [%] specified', dyn_profile.replace_rule, dyn_profile.preserve_rule;
        RETURN FALSE;
    END IF;

    IF dyn_profile.replace_rule <> '' THEN
        source_marc = v_marc;
        target_marc = eg_marc;
        replace_rule = dyn_profile.replace_rule;
    ELSE
        source_marc = eg_marc;
        target_marc = v_marc;
        replace_rule = dyn_profile.preserve_rule;
    END IF;

    UPDATE  biblio.record_entry
      SET   marc = vandelay.merge_record_xml( target_marc, source_marc, dyn_profile.add_rule, replace_rule, dyn_profile.strip_rule )
      WHERE id = eg_id;

    IF NOT FOUND THEN
        -- RAISE NOTICE 'update of biblio.record_entry failed';
        RETURN FALSE;
    END IF;

    RETURN TRUE;

END;
$$ LANGUAGE PLPGSQL;

CREATE OR REPLACE FUNCTION vandelay.merge_record_xml ( target_marc TEXT, template_marc TEXT ) RETURNS TEXT AS $$
DECLARE
    dyn_profile     vandelay.compile_profile%ROWTYPE;
    replace_rule    TEXT;
    tmp_marc        TEXT;
    trgt_marc        TEXT;
    tmpl_marc        TEXT;
    match_count     INT;
BEGIN

    IF target_marc IS NULL OR template_marc IS NULL THEN
        -- RAISE NOTICE 'no marc for target or template record';
        RETURN NULL;
    END IF;

    dyn_profile := vandelay.compile_profile( template_marc );

    IF dyn_profile.replace_rule <> '' AND dyn_profile.preserve_rule <> '' THEN
        -- RAISE NOTICE 'both replace [%] and preserve [%] specified', dyn_profile.replace_rule, dyn_profile.preserve_rule;
        RETURN NULL;
    END IF;

    IF dyn_profile.replace_rule <> '' THEN
        trgt_marc = target_marc;
        tmpl_marc = template_marc;
        replace_rule = dyn_profile.replace_rule;
    ELSE
        tmp_marc = target_marc;
        trgt_marc = template_marc;
        tmpl_marc = tmp_marc;
        replace_rule = dyn_profile.preserve_rule;
    END IF;

    RETURN vandelay.merge_record_xml( trgt_marc, tmpl_marc, dyn_profile.add_rule, replace_rule, dyn_profile.strip_rule );

END;
$$ LANGUAGE PLPGSQL;

CREATE OR REPLACE FUNCTION vandelay.template_overlay_bib_record ( v_marc TEXT, eg_id BIGINT) RETURNS BOOL AS $$
    SELECT vandelay.template_overlay_bib_record( $1, $2, NULL);
$$ LANGUAGE SQL;

CREATE OR REPLACE FUNCTION vandelay.overlay_bib_record ( import_id BIGINT, eg_id BIGINT, merge_profile_id INT ) RETURNS BOOL AS $$
DECLARE
    merge_profile   vandelay.merge_profile%ROWTYPE;
    dyn_profile     vandelay.compile_profile%ROWTYPE;
    editor_string   TEXT;
    editor_id       INT;
    source_marc     TEXT;
    target_marc     TEXT;
    eg_marc         TEXT;
    v_marc          TEXT;
    replace_rule    TEXT;
    match_count     INT;
BEGIN

    SELECT  q.marc INTO v_marc
      FROM  vandelay.queued_record q
            JOIN vandelay.bib_match m ON (m.queued_record = q.id AND q.id = import_id)
      LIMIT 1;

    IF v_marc IS NULL THEN
        -- RAISE NOTICE 'no marc for vandelay or bib record';
        RETURN FALSE;
    END IF;

    IF vandelay.template_overlay_bib_record( v_marc, eg_id, merge_profile_id) THEN
        UPDATE  vandelay.queued_bib_record
          SET   imported_as = eg_id,
                import_time = NOW()
          WHERE id = import_id;

        editor_string := (oils_xpath('//*[@tag="905"]/*[@code="u"]/text()',v_marc))[1];

        IF editor_string IS NOT NULL AND editor_string <> '' THEN
            SELECT usr INTO editor_id FROM actor.card WHERE barcode = editor_string;

            IF editor_id IS NULL THEN
                SELECT id INTO editor_id FROM actor.usr WHERE usrname = editor_string;
            END IF;

            IF editor_id IS NOT NULL THEN
                UPDATE biblio.record_entry SET editor = editor_id WHERE id = eg_id;
            END IF;
        END IF;

        RETURN TRUE;
    END IF;

    -- RAISE NOTICE 'update of biblio.record_entry failed';

    RETURN FALSE;

END;
$$ LANGUAGE PLPGSQL;

CREATE OR REPLACE FUNCTION vandelay.auto_overlay_bib_record ( import_id BIGINT, merge_profile_id INT ) RETURNS BOOL AS $$
DECLARE
    eg_id           BIGINT;
    match_count     INT;
    match_attr      vandelay.bib_attr_definition%ROWTYPE;
BEGIN

    PERFORM * FROM vandelay.queued_bib_record WHERE import_time IS NOT NULL AND id = import_id;

    IF FOUND THEN
        -- RAISE NOTICE 'already imported, cannot auto-overlay'
        RETURN FALSE;
    END IF;

    SELECT COUNT(*) INTO match_count FROM vandelay.bib_match WHERE queued_record = import_id;

    IF match_count <> 1 THEN
        -- RAISE NOTICE 'not an exact match';
        RETURN FALSE;
    END IF;

    SELECT  d.* INTO match_attr
      FROM  vandelay.bib_attr_definition d
            JOIN vandelay.queued_bib_record_attr a ON (a.field = d.id)
            JOIN vandelay.bib_match m ON (m.matched_attr = a.id)
      WHERE m.queued_record = import_id;

    IF NOT (match_attr.xpath ~ '@tag="901"' AND match_attr.xpath ~ '@code="c"') THEN
        -- RAISE NOTICE 'not a 901c match: %', match_attr.xpath;
        RETURN FALSE;
    END IF;

    SELECT  m.eg_record INTO eg_id
      FROM  vandelay.bib_match m
      WHERE m.queued_record = import_id
      LIMIT 1;

    IF eg_id IS NULL THEN
        RETURN FALSE;
    END IF;

    RETURN vandelay.overlay_bib_record( import_id, eg_id, merge_profile_id );
END;
$$ LANGUAGE PLPGSQL;

CREATE OR REPLACE FUNCTION vandelay.auto_overlay_bib_queue ( queue_id BIGINT, merge_profile_id INT ) RETURNS SETOF BIGINT AS $$
DECLARE
    queued_record   vandelay.queued_bib_record%ROWTYPE;
BEGIN

    FOR queued_record IN SELECT * FROM vandelay.queued_bib_record WHERE queue = queue_id AND import_time IS NULL LOOP

        IF vandelay.auto_overlay_bib_record( queued_record.id, merge_profile_id ) THEN
            RETURN NEXT queued_record.id;
        END IF;

    END LOOP;

    RETURN;
    
END;
$$ LANGUAGE PLPGSQL;

CREATE OR REPLACE FUNCTION vandelay.auto_overlay_bib_queue ( queue_id BIGINT ) RETURNS SETOF BIGINT AS $$
    SELECT * FROM vandelay.auto_overlay_bib_queue( $1, NULL );
$$ LANGUAGE SQL;

CREATE OR REPLACE FUNCTION vandelay.ingest_items ( import_id BIGINT, attr_def_id BIGINT ) RETURNS SETOF vandelay.import_item AS $$
DECLARE

    owning_lib      TEXT;
    circ_lib        TEXT;
    call_number     TEXT;
    copy_number     TEXT;
    status          TEXT;
    location        TEXT;
    circulate       TEXT;
    deposit         TEXT;
    deposit_amount  TEXT;
    ref             TEXT;
    holdable        TEXT;
    price           TEXT;
    barcode         TEXT;
    circ_modifier   TEXT;
    circ_as_type    TEXT;
    alert_message   TEXT;
    opac_visible    TEXT;
    pub_note        TEXT;
    priv_note       TEXT;

    attr_def        RECORD;
    tmp_attr_set    RECORD;
    attr_set        vandelay.import_item%ROWTYPE;

    xpath           TEXT;

BEGIN

    SELECT * INTO attr_def FROM vandelay.import_item_attr_definition WHERE id = attr_def_id;

    IF FOUND THEN

        attr_set.definition := attr_def.id; 
    
        -- Build the combined XPath
    
        owning_lib :=
            CASE
                WHEN attr_def.owning_lib IS NULL THEN 'null()'
                WHEN LENGTH( attr_def.owning_lib ) = 1 THEN '//*[@tag="' || attr_def.tag || '"]/*[@code="' || attr_def.owning_lib || '"]'
                ELSE '//*[@tag="' || attr_def.tag || '"]/*' || attr_def.owning_lib
            END;
    
        circ_lib :=
            CASE
                WHEN attr_def.circ_lib IS NULL THEN 'null()'
                WHEN LENGTH( attr_def.circ_lib ) = 1 THEN '//*[@tag="' || attr_def.tag || '"]/*[@code="' || attr_def.circ_lib || '"]'
                ELSE '//*[@tag="' || attr_def.tag || '"]/*' || attr_def.circ_lib
            END;
    
        call_number :=
            CASE
                WHEN attr_def.call_number IS NULL THEN 'null()'
                WHEN LENGTH( attr_def.call_number ) = 1 THEN '//*[@tag="' || attr_def.tag || '"]/*[@code="' || attr_def.call_number || '"]'
                ELSE '//*[@tag="' || attr_def.tag || '"]/*' || attr_def.call_number
            END;
    
        copy_number :=
            CASE
                WHEN attr_def.copy_number IS NULL THEN 'null()'
                WHEN LENGTH( attr_def.copy_number ) = 1 THEN '//*[@tag="' || attr_def.tag || '"]/*[@code="' || attr_def.copy_number || '"]'
                ELSE '//*[@tag="' || attr_def.tag || '"]/*' || attr_def.copy_number
            END;
    
        status :=
            CASE
                WHEN attr_def.status IS NULL THEN 'null()'
                WHEN LENGTH( attr_def.status ) = 1 THEN '//*[@tag="' || attr_def.tag || '"]/*[@code="' || attr_def.status || '"]'
                ELSE '//*[@tag="' || attr_def.tag || '"]/*' || attr_def.status
            END;
    
        location :=
            CASE
                WHEN attr_def.location IS NULL THEN 'null()'
                WHEN LENGTH( attr_def.location ) = 1 THEN '//*[@tag="' || attr_def.tag || '"]/*[@code="' || attr_def.location || '"]'
                ELSE '//*[@tag="' || attr_def.tag || '"]/*' || attr_def.location
            END;
    
        circulate :=
            CASE
                WHEN attr_def.circulate IS NULL THEN 'null()'
                WHEN LENGTH( attr_def.circulate ) = 1 THEN '//*[@tag="' || attr_def.tag || '"]/*[@code="' || attr_def.circulate || '"]'
                ELSE '//*[@tag="' || attr_def.tag || '"]/*' || attr_def.circulate
            END;
    
        deposit :=
            CASE
                WHEN attr_def.deposit IS NULL THEN 'null()'
                WHEN LENGTH( attr_def.deposit ) = 1 THEN '//*[@tag="' || attr_def.tag || '"]/*[@code="' || attr_def.deposit || '"]'
                ELSE '//*[@tag="' || attr_def.tag || '"]/*' || attr_def.deposit
            END;
    
        deposit_amount :=
            CASE
                WHEN attr_def.deposit_amount IS NULL THEN 'null()'
                WHEN LENGTH( attr_def.deposit_amount ) = 1 THEN '//*[@tag="' || attr_def.tag || '"]/*[@code="' || attr_def.deposit_amount || '"]'
                ELSE '//*[@tag="' || attr_def.tag || '"]/*' || attr_def.deposit_amount
            END;
    
        ref :=
            CASE
                WHEN attr_def.ref IS NULL THEN 'null()'
                WHEN LENGTH( attr_def.ref ) = 1 THEN '//*[@tag="' || attr_def.tag || '"]/*[@code="' || attr_def.ref || '"]'
                ELSE '//*[@tag="' || attr_def.tag || '"]/*' || attr_def.ref
            END;
    
        holdable :=
            CASE
                WHEN attr_def.holdable IS NULL THEN 'null()'
                WHEN LENGTH( attr_def.holdable ) = 1 THEN '//*[@tag="' || attr_def.tag || '"]/*[@code="' || attr_def.holdable || '"]'
                ELSE '//*[@tag="' || attr_def.tag || '"]/*' || attr_def.holdable
            END;
    
        price :=
            CASE
                WHEN attr_def.price IS NULL THEN 'null()'
                WHEN LENGTH( attr_def.price ) = 1 THEN '//*[@tag="' || attr_def.tag || '"]/*[@code="' || attr_def.price || '"]'
                ELSE '//*[@tag="' || attr_def.tag || '"]/*' || attr_def.price
            END;
    
        barcode :=
            CASE
                WHEN attr_def.barcode IS NULL THEN 'null()'
                WHEN LENGTH( attr_def.barcode ) = 1 THEN '//*[@tag="' || attr_def.tag || '"]/*[@code="' || attr_def.barcode || '"]'
                ELSE '//*[@tag="' || attr_def.tag || '"]/*' || attr_def.barcode
            END;
    
        circ_modifier :=
            CASE
                WHEN attr_def.circ_modifier IS NULL THEN 'null()'
                WHEN LENGTH( attr_def.circ_modifier ) = 1 THEN '//*[@tag="' || attr_def.tag || '"]/*[@code="' || attr_def.circ_modifier || '"]'
                ELSE '//*[@tag="' || attr_def.tag || '"]/*' || attr_def.circ_modifier
            END;
    
        circ_as_type :=
            CASE
                WHEN attr_def.circ_as_type IS NULL THEN 'null()'
                WHEN LENGTH( attr_def.circ_as_type ) = 1 THEN '//*[@tag="' || attr_def.tag || '"]/*[@code="' || attr_def.circ_as_type || '"]'
                ELSE '//*[@tag="' || attr_def.tag || '"]/*' || attr_def.circ_as_type
            END;
    
        alert_message :=
            CASE
                WHEN attr_def.alert_message IS NULL THEN 'null()'
                WHEN LENGTH( attr_def.alert_message ) = 1 THEN '//*[@tag="' || attr_def.tag || '"]/*[@code="' || attr_def.alert_message || '"]'
                ELSE '//*[@tag="' || attr_def.tag || '"]/*' || attr_def.alert_message
            END;
    
        opac_visible :=
            CASE
                WHEN attr_def.opac_visible IS NULL THEN 'null()'
                WHEN LENGTH( attr_def.opac_visible ) = 1 THEN '//*[@tag="' || attr_def.tag || '"]/*[@code="' || attr_def.opac_visible || '"]'
                ELSE '//*[@tag="' || attr_def.tag || '"]/*' || attr_def.opac_visible
            END;

        pub_note :=
            CASE
                WHEN attr_def.pub_note IS NULL THEN 'null()'
                WHEN LENGTH( attr_def.pub_note ) = 1 THEN '//*[@tag="' || attr_def.tag || '"]/*[@code="' || attr_def.pub_note || '"]'
                ELSE '//*[@tag="' || attr_def.tag || '"]/*' || attr_def.pub_note
            END;
        priv_note :=
            CASE
                WHEN attr_def.priv_note IS NULL THEN 'null()'
                WHEN LENGTH( attr_def.priv_note ) = 1 THEN '//*[@tag="' || attr_def.tag || '"]/*[@code="' || attr_def.priv_note || '"]'
                ELSE '//*[@tag="' || attr_def.tag || '"]/*' || attr_def.priv_note
            END;
    
    
        xpath := 
            owning_lib      || '|' || 
            circ_lib        || '|' || 
            call_number     || '|' || 
            copy_number     || '|' || 
            status          || '|' || 
            location        || '|' || 
            circulate       || '|' || 
            deposit         || '|' || 
            deposit_amount  || '|' || 
            ref             || '|' || 
            holdable        || '|' || 
            price           || '|' || 
            barcode         || '|' || 
            circ_modifier   || '|' || 
            circ_as_type    || '|' || 
            alert_message   || '|' || 
            pub_note        || '|' || 
            priv_note       || '|' || 
            opac_visible;

        -- RAISE NOTICE 'XPath: %', xpath;
        
        FOR tmp_attr_set IN
                SELECT  *
                  FROM  oils_xpath_table( 'id', 'marc', 'vandelay.queued_bib_record', xpath, 'id = ' || import_id )
                            AS t( id INT, ol TEXT, clib TEXT, cn TEXT, cnum TEXT, cs TEXT, cl TEXT, circ TEXT,
                                  dep TEXT, dep_amount TEXT, r TEXT, hold TEXT, pr TEXT, bc TEXT, circ_mod TEXT,
                                  circ_as TEXT, amessage TEXT, note TEXT, pnote TEXT, opac_vis TEXT )
        LOOP
    
            tmp_attr_set.pr = REGEXP_REPLACE(tmp_attr_set.pr, E'[^0-9\\.]', '', 'g');
            tmp_attr_set.dep_amount = REGEXP_REPLACE(tmp_attr_set.dep_amount, E'[^0-9\\.]', '', 'g');

            tmp_attr_set.pr := NULLIF( tmp_attr_set.pr, '' );
            tmp_attr_set.dep_amount := NULLIF( tmp_attr_set.dep_amount, '' );
    
            SELECT id INTO attr_set.owning_lib FROM actor.org_unit WHERE shortname = UPPER(tmp_attr_set.ol); -- INT
            SELECT id INTO attr_set.circ_lib FROM actor.org_unit WHERE shortname = UPPER(tmp_attr_set.clib); -- INT
            SELECT id INTO attr_set.status FROM config.copy_status WHERE LOWER(name) = LOWER(tmp_attr_set.cs); -- INT
    
            SELECT  id INTO attr_set.location
              FROM  asset.copy_location
              WHERE LOWER(name) = LOWER(tmp_attr_set.cl)
                    AND asset.copy_location.owning_lib = COALESCE(attr_set.owning_lib, attr_set.circ_lib); -- INT
    
            attr_set.circulate      :=
                LOWER( SUBSTRING( tmp_attr_set.circ, 1, 1)) IN ('t','y','1')
                OR LOWER(tmp_attr_set.circ) = 'circulating'; -- BOOL

            attr_set.deposit        :=
                LOWER( SUBSTRING( tmp_attr_set.dep, 1, 1 ) ) IN ('t','y','1')
                OR LOWER(tmp_attr_set.dep) = 'deposit'; -- BOOL

            attr_set.holdable       :=
                LOWER( SUBSTRING( tmp_attr_set.hold, 1, 1 ) ) IN ('t','y','1')
                OR LOWER(tmp_attr_set.hold) = 'holdable'; -- BOOL

            attr_set.opac_visible   :=
                LOWER( SUBSTRING( tmp_attr_set.opac_vis, 1, 1 ) ) IN ('t','y','1')
                OR LOWER(tmp_attr_set.opac_vis) = 'visible'; -- BOOL

            attr_set.ref            :=
                LOWER( SUBSTRING( tmp_attr_set.r, 1, 1 ) ) IN ('t','y','1')
                OR LOWER(tmp_attr_set.r) = 'reference'; -- BOOL
    
            attr_set.copy_number    := tmp_attr_set.cnum::INT; -- INT,
            attr_set.deposit_amount := tmp_attr_set.dep_amount::NUMERIC(6,2); -- NUMERIC(6,2),
            attr_set.price          := tmp_attr_set.pr::NUMERIC(8,2); -- NUMERIC(8,2),
    
            attr_set.call_number    := tmp_attr_set.cn; -- TEXT
            attr_set.barcode        := tmp_attr_set.bc; -- TEXT,
            attr_set.circ_modifier  := tmp_attr_set.circ_mod; -- TEXT,
            attr_set.circ_as_type   := tmp_attr_set.circ_as; -- TEXT,
            attr_set.alert_message  := tmp_attr_set.amessage; -- TEXT,
            attr_set.pub_note       := tmp_attr_set.note; -- TEXT,
            attr_set.priv_note      := tmp_attr_set.pnote; -- TEXT,
            attr_set.alert_message  := tmp_attr_set.amessage; -- TEXT,
    
            RETURN NEXT attr_set;
    
        END LOOP;
    
    END IF;

    RETURN;

END;
$$ LANGUAGE PLPGSQL;


CREATE OR REPLACE FUNCTION vandelay.ingest_bib_marc ( ) RETURNS TRIGGER AS $$
DECLARE
    value   TEXT;
    atype   TEXT;
    adef    RECORD;
BEGIN
    FOR adef IN SELECT * FROM vandelay.bib_attr_definition LOOP

        SELECT extract_marc_field('vandelay.queued_bib_record', id, adef.xpath, adef.remove) INTO value FROM vandelay.queued_bib_record WHERE id = NEW.id;
        IF (value IS NOT NULL AND value <> '') THEN
            INSERT INTO vandelay.queued_bib_record_attr (record, field, attr_value) VALUES (NEW.id, adef.id, value);
        END IF;

    END LOOP;

    RETURN NULL;
END;
$$ LANGUAGE PLPGSQL;

CREATE OR REPLACE FUNCTION vandelay.ingest_bib_items ( ) RETURNS TRIGGER AS $func$
DECLARE
    attr_def    BIGINT;
    item_data   vandelay.import_item%ROWTYPE;
BEGIN

    SELECT item_attr_def INTO attr_def FROM vandelay.bib_queue WHERE id = NEW.queue;

    FOR item_data IN SELECT * FROM vandelay.ingest_items( NEW.id::BIGINT, attr_def ) LOOP
        INSERT INTO vandelay.import_item (
            record,
            definition,
            owning_lib,
            circ_lib,
            call_number,
            copy_number,
            status,
            location,
            circulate,
            deposit,
            deposit_amount,
            ref,
            holdable,
            price,
            barcode,
            circ_modifier,
            circ_as_type,
            alert_message,
            pub_note,
            priv_note,
            opac_visible
        ) VALUES (
            NEW.id,
            item_data.definition,
            item_data.owning_lib,
            item_data.circ_lib,
            item_data.call_number,
            item_data.copy_number,
            item_data.status,
            item_data.location,
            item_data.circulate,
            item_data.deposit,
            item_data.deposit_amount,
            item_data.ref,
            item_data.holdable,
            item_data.price,
            item_data.barcode,
            item_data.circ_modifier,
            item_data.circ_as_type,
            item_data.alert_message,
            item_data.pub_note,
            item_data.priv_note,
            item_data.opac_visible
        );
    END LOOP;

    RETURN NULL;
END;
$func$ LANGUAGE PLPGSQL;

CREATE OR REPLACE FUNCTION vandelay.match_bib_record ( ) RETURNS TRIGGER AS $func$
DECLARE
    attr        RECORD;
    attr_def    RECORD;
    eg_rec      RECORD;
    id_value    TEXT;
    exact_id    BIGINT;
BEGIN

    DELETE FROM vandelay.bib_match WHERE queued_record = NEW.id;

    SELECT * INTO attr_def FROM vandelay.bib_attr_definition WHERE xpath = '//*[@tag="901"]/*[@code="c"]' ORDER BY id LIMIT 1;

    IF attr_def IS NOT NULL AND attr_def.id IS NOT NULL THEN
        id_value := extract_marc_field('vandelay.queued_bib_record', NEW.id, attr_def.xpath, attr_def.remove);
    
        IF id_value IS NOT NULL AND id_value <> '' AND id_value ~ $r$^\d+$$r$ THEN
            SELECT id INTO exact_id FROM biblio.record_entry WHERE id = id_value::BIGINT AND NOT deleted;
            SELECT * INTO attr FROM vandelay.queued_bib_record_attr WHERE record = NEW.id and field = attr_def.id LIMIT 1;
            IF exact_id IS NOT NULL THEN
                INSERT INTO vandelay.bib_match (field_type, matched_attr, queued_record, eg_record) VALUES ('id', attr.id, NEW.id, exact_id);
            END IF;
        END IF;
    END IF;

    IF exact_id IS NULL THEN
        FOR attr IN SELECT a.* FROM vandelay.queued_bib_record_attr a JOIN vandelay.bib_attr_definition d ON (d.id = a.field) WHERE record = NEW.id AND d.ident IS TRUE LOOP
    
    		-- All numbers? check for an id match
    		IF (attr.attr_value ~ $r$^\d+$$r$) THEN
    	        FOR eg_rec IN SELECT * FROM biblio.record_entry WHERE id = attr.attr_value::BIGINT AND deleted IS FALSE LOOP
    		        INSERT INTO vandelay.bib_match (field_type, matched_attr, queued_record, eg_record) VALUES ('id', attr.id, NEW.id, eg_rec.id);
    			END LOOP;
    		END IF;
    
    		-- Looks like an ISBN? check for an isbn match
    		IF (attr.attr_value ~* $r$^[0-9x]+$$r$ AND character_length(attr.attr_value) IN (10,13)) THEN
    	        FOR eg_rec IN EXECUTE $$SELECT * FROM metabib.full_rec fr WHERE fr.value LIKE LOWER('$$ || attr.attr_value || $$%') AND fr.tag = '020' AND fr.subfield = 'a'$$ LOOP
    				PERFORM id FROM biblio.record_entry WHERE id = eg_rec.record AND deleted IS FALSE;
    				IF FOUND THEN
    			        INSERT INTO vandelay.bib_match (field_type, matched_attr, queued_record, eg_record) VALUES ('isbn', attr.id, NEW.id, eg_rec.record);
    				END IF;
    			END LOOP;
    
    			-- subcheck for isbn-as-tcn
    		    FOR eg_rec IN SELECT * FROM biblio.record_entry WHERE tcn_value = 'i' || attr.attr_value AND deleted IS FALSE LOOP
    			    INSERT INTO vandelay.bib_match (field_type, matched_attr, queued_record, eg_record) VALUES ('tcn_value', attr.id, NEW.id, eg_rec.id);
    	        END LOOP;
    		END IF;
    
    		-- check for an OCLC tcn_value match
    		IF (attr.attr_value ~ $r$^o\d+$$r$) THEN
    		    FOR eg_rec IN SELECT * FROM biblio.record_entry WHERE tcn_value = regexp_replace(attr.attr_value,'^o','ocm') AND deleted IS FALSE LOOP
    			    INSERT INTO vandelay.bib_match (field_type, matched_attr, queued_record, eg_record) VALUES ('tcn_value', attr.id, NEW.id, eg_rec.id);
    	        END LOOP;
    		END IF;
    
    		-- check for a direct tcn_value match
            FOR eg_rec IN SELECT * FROM biblio.record_entry WHERE tcn_value = attr.attr_value AND deleted IS FALSE LOOP
                INSERT INTO vandelay.bib_match (field_type, matched_attr, queued_record, eg_record) VALUES ('tcn_value', attr.id, NEW.id, eg_rec.id);
            END LOOP;
    
    		-- check for a direct item barcode match
            FOR eg_rec IN
                    SELECT  DISTINCT b.*
                      FROM  biblio.record_entry b
                            JOIN asset.call_number cn ON (cn.record = b.id)
                            JOIN asset.copy cp ON (cp.call_number = cn.id)
                      WHERE cp.barcode = attr.attr_value AND cp.deleted IS FALSE
            LOOP
                INSERT INTO vandelay.bib_match (field_type, matched_attr, queued_record, eg_record) VALUES ('id', attr.id, NEW.id, eg_rec.id);
            END LOOP;
    
        END LOOP;
    END IF;

    RETURN NULL;
END;
$func$ LANGUAGE PLPGSQL;

CREATE OR REPLACE FUNCTION vandelay.cleanup_bib_marc ( ) RETURNS TRIGGER AS $$
BEGIN
    DELETE FROM vandelay.queued_bib_record_attr WHERE record = OLD.id;
    DELETE FROM vandelay.import_item WHERE record = OLD.id;

    IF TG_OP = 'UPDATE' THEN
        RETURN NEW;
    END IF;
    RETURN OLD;
END;
$$ LANGUAGE PLPGSQL;

CREATE TRIGGER cleanup_bib_trigger
    BEFORE UPDATE OR DELETE ON vandelay.queued_bib_record
    FOR EACH ROW EXECUTE PROCEDURE vandelay.cleanup_bib_marc();

CREATE TRIGGER ingest_bib_trigger
    AFTER INSERT OR UPDATE ON vandelay.queued_bib_record
    FOR EACH ROW EXECUTE PROCEDURE vandelay.ingest_bib_marc();

CREATE TRIGGER ingest_item_trigger
    AFTER INSERT OR UPDATE ON vandelay.queued_bib_record
    FOR EACH ROW EXECUTE PROCEDURE vandelay.ingest_bib_items();

CREATE TRIGGER zz_match_bibs_trigger
    AFTER INSERT OR UPDATE ON vandelay.queued_bib_record
    FOR EACH ROW EXECUTE PROCEDURE vandelay.match_bib_record();


/* Authority stuff down here */
---------------------------------------
CREATE TABLE vandelay.authority_attr_definition (
	id			SERIAL	PRIMARY KEY,
	code		TEXT	UNIQUE NOT NULL,
	description	TEXT,
	xpath		TEXT	NOT NULL,
	remove		TEXT	NOT NULL DEFAULT '',
	ident		BOOL	NOT NULL DEFAULT FALSE
);

CREATE TABLE vandelay.authority_queue (
	queue_type	TEXT		NOT NULL DEFAULT 'authority' CHECK (queue_type = 'authority'),
	CONSTRAINT vand_authority_queue_name_once_per_owner_const UNIQUE (owner,name,queue_type)
) INHERITS (vandelay.queue);
ALTER TABLE vandelay.authority_queue ADD PRIMARY KEY (id);

CREATE TABLE vandelay.queued_authority_record (
	queue		INT	NOT NULL REFERENCES vandelay.authority_queue (id) ON DELETE CASCADE DEFERRABLE INITIALLY DEFERRED,
	imported_as	INT	REFERENCES authority.record_entry (id) DEFERRABLE INITIALLY DEFERRED
) INHERITS (vandelay.queued_record);
ALTER TABLE vandelay.queued_authority_record ADD PRIMARY KEY (id);
CREATE INDEX queued_authority_record_queue_idx ON vandelay.queued_authority_record (queue);

CREATE TABLE vandelay.queued_authority_record_attr (
	id			BIGSERIAL	PRIMARY KEY,
	record		BIGINT		NOT NULL REFERENCES vandelay.queued_authority_record (id) DEFERRABLE INITIALLY DEFERRED,
	field		INT			NOT NULL REFERENCES vandelay.authority_attr_definition (id) DEFERRABLE INITIALLY DEFERRED,
	attr_value	TEXT		NOT NULL
);
CREATE INDEX queued_authority_record_attr_record_idx ON vandelay.queued_authority_record_attr (record);

CREATE TABLE vandelay.authority_match (
	id				BIGSERIAL	PRIMARY KEY,
	matched_attr	INT			REFERENCES vandelay.queued_authority_record_attr (id) ON DELETE CASCADE DEFERRABLE INITIALLY DEFERRED,
	queued_record	BIGINT		REFERENCES vandelay.queued_authority_record (id) ON DELETE CASCADE DEFERRABLE INITIALLY DEFERRED,
	eg_record		BIGINT		REFERENCES authority.record_entry (id) DEFERRABLE INITIALLY DEFERRED
);

CREATE OR REPLACE FUNCTION vandelay.ingest_authority_marc ( ) RETURNS TRIGGER AS $$
DECLARE
    value   TEXT;
    atype   TEXT;
    adef    RECORD;
BEGIN
    FOR adef IN SELECT * FROM vandelay.authority_attr_definition LOOP

        SELECT extract_marc_field('vandelay.queued_authority_record', id, adef.xpath, adef.remove) INTO value FROM vandelay.queued_authority_record WHERE id = NEW.id;
        IF (value IS NOT NULL AND value <> '') THEN
            INSERT INTO vandelay.queued_authority_record_attr (record, field, attr_value) VALUES (NEW.id, adef.id, value);
        END IF;

    END LOOP;

    RETURN NULL;
END;
$$ LANGUAGE PLPGSQL;

CREATE OR REPLACE FUNCTION vandelay.cleanup_authority_marc ( ) RETURNS TRIGGER AS $$
BEGIN
    DELETE FROM vandelay.queued_authority_record_attr WHERE record = OLD.id;
    IF TG_OP = 'UPDATE' THEN
        RETURN NEW;
    END IF;
    RETURN OLD;
END;
$$ LANGUAGE PLPGSQL;

CREATE TRIGGER cleanup_authority_trigger
    BEFORE UPDATE OR DELETE ON vandelay.queued_authority_record
    FOR EACH ROW EXECUTE PROCEDURE vandelay.cleanup_authority_marc();

CREATE TRIGGER ingest_authority_trigger
    AFTER INSERT OR UPDATE ON vandelay.queued_authority_record
    FOR EACH ROW EXECUTE PROCEDURE vandelay.ingest_authority_marc();

CREATE OR REPLACE FUNCTION vandelay.overlay_authority_record ( import_id BIGINT, eg_id BIGINT, merge_profile_id INT ) RETURNS BOOL AS $$
DECLARE
    merge_profile   vandelay.merge_profile%ROWTYPE;
    dyn_profile     vandelay.compile_profile%ROWTYPE;
    source_marc     TEXT;
    target_marc     TEXT;
    eg_marc         TEXT;
    v_marc          TEXT;
    replace_rule    TEXT;
    match_count     INT;
BEGIN

    SELECT  b.marc INTO eg_marc
      FROM  authority.record_entry b
            JOIN vandelay.authority_match m ON (m.eg_record = b.id AND m.queued_record = import_id)
      LIMIT 1;

    SELECT  q.marc INTO v_marc
      FROM  vandelay.queued_record q
            JOIN vandelay.authority_match m ON (m.queued_record = q.id AND q.id = import_id)
      LIMIT 1;

    IF eg_marc IS NULL OR v_marc IS NULL THEN
        -- RAISE NOTICE 'no marc for vandelay or authority record';
        RETURN FALSE;
    END IF;

    dyn_profile := vandelay.compile_profile( v_marc );

    IF merge_profile_id IS NOT NULL THEN
        SELECT * INTO merge_profile FROM vandelay.merge_profile WHERE id = merge_profile_id;
        IF FOUND THEN
            dyn_profile.add_rule := BTRIM( dyn_profile.add_rule || ',' || COALESCE(merge_profile.add_spec,''), ',');
            dyn_profile.strip_rule := BTRIM( dyn_profile.strip_rule || ',' || COALESCE(merge_profile.strip_spec,''), ',');
            dyn_profile.replace_rule := BTRIM( dyn_profile.replace_rule || ',' || COALESCE(merge_profile.replace_spec,''), ',');
            dyn_profile.preserve_rule := BTRIM( dyn_profile.preserve_rule || ',' || COALESCE(merge_profile.preserve_spec,''), ',');
        END IF;
    END IF;

    IF dyn_profile.replace_rule <> '' AND dyn_profile.preserve_rule <> '' THEN
        -- RAISE NOTICE 'both replace [%] and preserve [%] specified', dyn_profile.replace_rule, dyn_profile.preserve_rule;
        RETURN FALSE;
    END IF;

    IF dyn_profile.replace_rule <> '' THEN
        source_marc = v_marc;
        target_marc = eg_marc;
        replace_rule = dyn_profile.replace_rule;
    ELSE
        source_marc = eg_marc;
        target_marc = v_marc;
        replace_rule = dyn_profile.preserve_rule;
    END IF;

    UPDATE  authority.record_entry
      SET   marc = vandelay.merge_record_xml( target_marc, source_marc, dyn_profile.add_rule, replace_rule, dyn_profile.strip_rule )
      WHERE id = eg_id;

    IF FOUND THEN
        UPDATE  vandelay.queued_authority_record
          SET   imported_as = eg_id,
                import_time = NOW()
          WHERE id = import_id;
        RETURN TRUE;
    END IF;

    -- RAISE NOTICE 'update of authority.record_entry failed';

    RETURN FALSE;

END;
$$ LANGUAGE PLPGSQL;

CREATE OR REPLACE FUNCTION vandelay.auto_overlay_authority_record ( import_id BIGINT, merge_profile_id INT ) RETURNS BOOL AS $$
DECLARE
    eg_id           BIGINT;
    match_count     INT;
BEGIN
    SELECT COUNT(*) INTO match_count FROM vandelay.authority_match WHERE queued_record = import_id;

    IF match_count <> 1 THEN
        -- RAISE NOTICE 'not an exact match';
        RETURN FALSE;
    END IF;

    SELECT  m.eg_record INTO eg_id
      FROM  vandelay.authority_match m
      WHERE m.queued_record = import_id
      LIMIT 1;

    IF eg_id IS NULL THEN
        RETURN FALSE;
    END IF;

    RETURN vandelay.overlay_authority_record( import_id, eg_id, merge_profile_id );
END;
$$ LANGUAGE PLPGSQL;

CREATE OR REPLACE FUNCTION vandelay.auto_overlay_authority_queue ( queue_id BIGINT, merge_profile_id INT ) RETURNS SETOF BIGINT AS $$
DECLARE
    queued_record   vandelay.queued_authority_record%ROWTYPE;
BEGIN

    FOR queued_record IN SELECT * FROM vandelay.queued_authority_record WHERE queue = queue_id AND import_time IS NULL LOOP

        IF vandelay.auto_overlay_authority_record( queued_record.id, merge_profile_id ) THEN
            RETURN NEXT queued_record.id;
        END IF;

    END LOOP;

    RETURN;
    
END;
$$ LANGUAGE PLPGSQL;

CREATE OR REPLACE FUNCTION vandelay.auto_overlay_authority_queue ( queue_id BIGINT ) RETURNS SETOF BIGINT AS $$
    SELECT * FROM vandelay.auto_overlay_authority_queue( $1, NULL );
$$ LANGUAGE SQL;


-- Vandelay (for importing and exporting records) 012.schema.vandelay.sql 
--INSERT INTO vandelay.bib_attr_definition ( id, code, description, xpath ) VALUES (1, 'title', oils_i18n_gettext(1, 'vqbrad', 'Title of work', 'description'),'//*[@tag="245"]/*[contains("abcmnopr",@code)]');
--INSERT INTO vandelay.bib_attr_definition ( id, code, description, xpath ) VALUES (2, 'author', oils_i18n_gettext(1, 'vqbrad', 'Author of work', 'description'),'//*[@tag="100" or @tag="110" or @tag="113"]/*[contains("ad",@code)]');
--INSERT INTO vandelay.bib_attr_definition ( id, code, description, xpath ) VALUES (3, 'language', oils_i18n_gettext(3, 'vqbrad', 'Language of work', 'description'),'//*[@tag="240"]/*[@code="l"][1]');
--INSERT INTO vandelay.bib_attr_definition ( id, code, description, xpath ) VALUES (4, 'pagination', oils_i18n_gettext(4, 'vqbrad', 'Pagination', 'description'),'//*[@tag="300"]/*[@code="a"][1]');
--INSERT INTO vandelay.bib_attr_definition ( id, code, description, xpath, ident, remove ) VALUES (5, 'isbn',oils_i18n_gettext(5, 'vqbrad', 'ISBN', 'description'),'//*[@tag="020"]/*[@code="a"]', TRUE, $r$(?:-|\s.+$)$r$);
--INSERT INTO vandelay.bib_attr_definition ( id, code, description, xpath, ident, remove ) VALUES (6, 'issn',oils_i18n_gettext(6, 'vqbrad', 'ISSN', 'description'),'//*[@tag="022"]/*[@code="a"]', TRUE, $r$(?:-|\s.+$)$r$);
--INSERT INTO vandelay.bib_attr_definition ( id, code, description, xpath ) VALUES (7, 'price',oils_i18n_gettext(7, 'vqbrad', 'Price', 'description'),'//*[@tag="020" or @tag="022"]/*[@code="c"][1]');
--INSERT INTO vandelay.bib_attr_definition ( id, code, description, xpath, ident ) VALUES (8, 'rec_identifier',oils_i18n_gettext(8, 'vqbrad', 'Accession Number', 'description'),'//*[@tag="001"]', TRUE);
--INSERT INTO vandelay.bib_attr_definition ( id, code, description, xpath, ident ) VALUES (9, 'eg_tcn',oils_i18n_gettext(9, 'vqbrad', 'TCN Value', 'description'),'//*[@tag="901"]/*[@code="a"]', TRUE);
--INSERT INTO vandelay.bib_attr_definition ( id, code, description, xpath, ident ) VALUES (10, 'eg_tcn_source',oils_i18n_gettext(10, 'vqbrad', 'TCN Source', 'description'),'//*[@tag="901"]/*[@code="b"]', TRUE);
--INSERT INTO vandelay.bib_attr_definition ( id, code, description, xpath, ident ) VALUES (11, 'eg_identifier',oils_i18n_gettext(11, 'vqbrad', 'Internal ID', 'description'),'//*[@tag="901"]/*[@code="c"]', TRUE);
--INSERT INTO vandelay.bib_attr_definition ( id, code, description, xpath ) VALUES (12, 'publisher',oils_i18n_gettext(12, 'vqbrad', 'Publisher', 'description'),'//*[@tag="260"]/*[@code="b"][1]');
--INSERT INTO vandelay.bib_attr_definition ( id, code, description, xpath, remove ) VALUES (13, 'pubdate',oils_i18n_gettext(13, 'vqbrad', 'Publication Date', 'description'),'//*[@tag="260"]/*[@code="c"][1]',$r$\D$r$);
--INSERT INTO vandelay.bib_attr_definition ( id, code, description, xpath ) VALUES (14, 'edition',oils_i18n_gettext(14, 'vqbrad', 'Edition', 'description'),'//*[@tag="250"]/*[@code="a"][1]');
--
--INSERT INTO vandelay.import_item_attr_definition (
--    owner, name, tag, owning_lib, circ_lib, location,
--    call_number, circ_modifier, barcode, price, copy_number,
--    circulate, ref, holdable, opac_visible, status
--) VALUES (
--    1,
--    'Evergreen 852 export format',
--    '852',
--    '[@code = "b"][1]',
--    '[@code = "b"][2]',
--    'c',
--    'j',
--    'g',
--    'p',
--    'y',
--    't',
--    '[@code = "x" and text() = "circulating"]',
--    '[@code = "x" and text() = "reference"]',
--    '[@code = "x" and text() = "holdable"]',
--    '[@code = "x" and text() = "visible"]',
--    'z'
--);
--
--INSERT INTO vandelay.import_item_attr_definition (
--    owner,
--    name,
--    tag,
--    owning_lib,
--    location,
--    call_number,
--    circ_modifier,
--    barcode,
--    price,
--    status
--) VALUES (
--    1,
--    'Unicorn Import format -- 999',
--    '999',
--    'm',
--    'l',
--    'a',
--    't',
--    'i',
--    'p',
--    'k'
--);
--
--INSERT INTO vandelay.authority_attr_definition ( code, description, xpath, ident ) VALUES ('rec_identifier','Identifier','//*[@tag="001"]', TRUE);

COMMIT;

