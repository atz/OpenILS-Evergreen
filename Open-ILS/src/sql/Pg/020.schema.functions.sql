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

CREATE OR REPLACE FUNCTION public.non_filing_normalize ( TEXT, "char" ) RETURNS TEXT AS $$
        SELECT  SUBSTRING(
                        REGEXP_REPLACE(
                                REGEXP_REPLACE(
                                        $1,
                                        E'\W*$',
					''
				),
                                '  ',
                                ' '
                        ),
                        CASE
				WHEN $2::INT NOT BETWEEN 48 AND 57 THEN 1
				ELSE $2::TEXT::INT + 1
			END
		);
$$ LANGUAGE SQL STRICT IMMUTABLE;

CREATE OR REPLACE FUNCTION public.naco_normalize( TEXT, TEXT ) RETURNS TEXT AS $func$
	use Unicode::Normalize;
	use Encode;

	# When working with Unicode data, the first step is to decode it to
	# a byte string; after that, lowercasing is safe
	my $txt = lc(decode_utf8(shift));
	my $sf = shift;

	$txt = NFD($txt);
	$txt =~ s/\pM+//go;	# Remove diacritics

	$txt =~ s/\xE6/AE/go;	# Convert ae digraph
	$txt =~ s/\x{153}/OE/go;# Convert oe digraph
	$txt =~ s/\xFE/TH/go;	# Convert Icelandic thorn

	$txt =~ tr/\x{2070}\x{2071}\x{2072}\x{2073}\x{2074}\x{2075}\x{2076}\x{2077}\x{2078}\x{2079}\x{207A}\x{207B}/0123456789+-/;# Convert superscript numbers
	$txt =~ tr/\x{2080}\x{2081}\x{2082}\x{2083}\x{2084}\x{2085}\x{2086}\x{2087}\x{2088}\x{2089}\x{208A}\x{208B}/0123456889+-/;# Convert subscript numbers

	$txt =~ tr/\x{0251}\x{03B1}\x{03B2}\x{0262}\x{03B3}/AABGG/;	 	# Convert Latin and Greek
	$txt =~ tr/\x{2113}\xF0\!\"\(\)\-\{\}\<\>\;\:\.\?\xA1\xBF\/\\\@\*\%\=\xB1\+\xAE\xA9\x{2117}\$\xA3\x{FFE1}\xB0\^\_\~\`/LD /;	# Convert Misc
	$txt =~ tr/\'\[\]\|//d;							# Remove Misc

	if ($sf && $sf =~ /^a/o) {
		my $commapos = index($txt,',');
		if ($commapos > -1) {
			if ($commapos != length($txt) - 1) {
				my @list = split /,/, $txt;
				my $first = shift @list;
				$txt = $first . ',' . join(' ', @list);
			} else {
				$txt =~ s/,/ /go;
			}
		}
	} else {
		$txt =~ s/,/ /go;
	}

	$txt =~ s/\s+/ /go;	# Compress multiple spaces
	$txt =~ s/^\s+//o;	# Remove leading space
	$txt =~ s/\s+$//o;	# Remove trailing space

	# Encoding the outgoing string is good practice, but not strictly
	# necessary in this case because we've stripped everything from it
	return encode_utf8($txt);
$func$ LANGUAGE 'plperlu' STRICT IMMUTABLE;

CREATE OR REPLACE FUNCTION public.naco_normalize( TEXT ) RETURNS TEXT AS $func$
	SELECT public.naco_normalize($1,'');
$func$ LANGUAGE 'sql' STRICT IMMUTABLE;

CREATE OR REPLACE FUNCTION public.first_word ( TEXT ) RETURNS TEXT AS $$
        SELECT COALESCE(SUBSTRING( $1 FROM $_$^\S+$_$), '');
$$ LANGUAGE SQL STRICT IMMUTABLE;

CREATE OR REPLACE FUNCTION public.naco_normalize_keep_comma( TEXT ) RETURNS TEXT AS $func$
        SELECT public.naco_normalize($1,'a');
$func$ LANGUAGE SQL STRICT IMMUTABLE;

CREATE OR REPLACE FUNCTION public.normalize_space( TEXT ) RETURNS TEXT AS $$
    SELECT regexp_replace(regexp_replace(regexp_replace($1, E'\\n', ' ', 'g'), E'(?:^\\s+)|(\\s+$)', '', 'g'), E'\\s+', ' ', 'g');
$$ LANGUAGE SQL STRICT IMMUTABLE;

CREATE OR REPLACE FUNCTION public.remove_commas( TEXT ) RETURNS TEXT AS $$
    SELECT regexp_replace($1, ',', '', 'g');
$$ LANGUAGE SQL STRICT IMMUTABLE;

CREATE OR REPLACE FUNCTION public.remove_paren_substring( TEXT ) RETURNS TEXT AS $func$
    SELECT regexp_replace($1, $$\([^)]+\)$$, '', 'g');
$func$ LANGUAGE SQL STRICT IMMUTABLE;

CREATE OR REPLACE FUNCTION public.remove_whitespace( TEXT ) RETURNS TEXT AS $$
    SELECT regexp_replace(normalize_space($1), E'\\s+', '', 'g');
$$ LANGUAGE SQL STRICT IMMUTABLE;

CREATE OR REPLACE FUNCTION public.lowercase( TEXT ) RETURNS TEXT AS $$
    return lc(shift);
$$ LANGUAGE PLPERLU STRICT IMMUTABLE;

CREATE OR REPLACE FUNCTION public.uppercase( TEXT ) RETURNS TEXT AS $$
    return uc(shift);
$$ LANGUAGE PLPERLU STRICT IMMUTABLE;

CREATE OR REPLACE FUNCTION public.remove_diacritics( TEXT ) RETURNS TEXT AS $$
    use Unicode::Normalize;

    my $x = NFD(shift);
    $x =~ s/\pM+//go;
    return $x;

$$ LANGUAGE PLPERLU STRICT IMMUTABLE;

CREATE OR REPLACE FUNCTION public.entityize( TEXT ) RETURNS TEXT AS $$
    use Unicode::Normalize;

    my $x = NFC(shift);
    $x =~ s/([\x{0080}-\x{fffd}])/sprintf('&#x%X;',ord($1))/sgoe;
    return $x;

$$ LANGUAGE PLPERLU STRICT IMMUTABLE;

CREATE OR REPLACE FUNCTION public.call_number_dewey( TEXT ) RETURNS TEXT AS $$
	my $txt = shift;
	$txt =~ s/^\s+//o;
	$txt =~ s/[\[\]\{\}\(\)`'"#<>\*\?\-\+\$\\]+//og;
	$txt =~ s/\s+$//o;
	if ($txt =~ /(\d{3}(?:\.\d+)?)/o) {
		return $1;
	} else {
		return (split /\s+/, $txt)[0];
	}
$$ LANGUAGE 'plperlu' STRICT IMMUTABLE;

CREATE OR REPLACE FUNCTION public.call_number_dewey( TEXT, INT ) RETURNS TEXT AS $$
	SELECT SUBSTRING(call_number_dewey($1) FROM 1 FOR $2);
$$ LANGUAGE SQL STRICT IMMUTABLE;

CREATE OR REPLACE FUNCTION tableoid2name ( oid ) RETURNS TEXT AS $$
	BEGIN
		RETURN $1::regclass;
	END;
$$ language 'plpgsql';


CREATE OR REPLACE FUNCTION actor.org_unit_descendants ( INT ) RETURNS SETOF actor.org_unit AS $$
	SELECT	a.*
	  FROM	connectby('actor.org_unit'::text,'id'::text,'parent_ou'::text,'name'::text,$1::text,100,'.'::text)
	  		AS t(keyid text, parent_keyid text, level int, branch text,pos int)
		JOIN actor.org_unit a ON a.id::text = t.keyid::text
	  ORDER BY  CASE WHEN a.parent_ou IS NULL THEN 0 ELSE 1 END, a.name;
$$ LANGUAGE SQL STABLE;

CREATE OR REPLACE FUNCTION actor.org_unit_ancestors ( INT ) RETURNS SETOF actor.org_unit AS $$
	SELECT	a.*
	  FROM	connectby('actor.org_unit'::text,'parent_ou'::text,'id'::text,'name'::text,$1::text,100,'.'::text)
	  		AS t(keyid text, parent_keyid text, level int, branch text,pos int)
		JOIN actor.org_unit a ON a.id::text = t.keyid::text
        JOIN actor.org_unit_type tp ON tp.id = a.ou_type 
        ORDER BY tp.depth, a.name;
$$ LANGUAGE SQL STABLE;

CREATE OR REPLACE FUNCTION actor.org_unit_descendants ( INT,INT ) RETURNS SETOF actor.org_unit AS $$
	SELECT	a.*
	  FROM	connectby('actor.org_unit'::text,'id'::text,'parent_ou'::text,'name'::text,
	  			(SELECT	x.id
				   FROM	actor.org_unit_ancestors($1) x
				   	JOIN actor.org_unit_type y ON x.ou_type = y.id
				  WHERE	y.depth = $2)::text
		,100,'.'::text)
	  		AS t(keyid text, parent_keyid text, level int, branch text,pos int)
		JOIN actor.org_unit a ON a.id::text = t.keyid::text
	  ORDER BY  CASE WHEN a.parent_ou IS NULL THEN 0 ELSE 1 END, a.name;
$$ LANGUAGE SQL STABLE;

CREATE OR REPLACE FUNCTION actor.org_unit_ancestor_at_depth ( INT,INT ) RETURNS actor.org_unit AS $$
	SELECT	a.*
	  FROM	actor.org_unit a
	  WHERE	id = ( SELECT FIRST(x.id)
	  		 FROM	actor.org_unit_ancestors($1) x
			   	JOIN actor.org_unit_type y
					ON x.ou_type = y.id AND y.depth = $2);
$$ LANGUAGE SQL STABLE;

CREATE OR REPLACE FUNCTION actor.org_unit_full_path ( INT ) RETURNS SETOF actor.org_unit AS $$
	SELECT	*
	  FROM	actor.org_unit_ancestors($1)
			UNION
	SELECT	*
	  FROM	actor.org_unit_descendants($1);
$$ LANGUAGE SQL STABLE;

CREATE OR REPLACE FUNCTION actor.org_unit_full_path ( INT, INT ) RETURNS SETOF actor.org_unit AS $$
	SELECT	* FROM actor.org_unit_full_path((actor.org_unit_ancestor_at_depth($1, $2)).id)
$$ LANGUAGE SQL STABLE;

CREATE OR REPLACE FUNCTION actor.org_unit_combined_ancestors ( INT, INT ) RETURNS SETOF actor.org_unit AS $$
	SELECT	*
	  FROM	actor.org_unit_ancestors($1)
			UNION
	SELECT	*
	  FROM	actor.org_unit_ancestors($2);
$$ LANGUAGE SQL STABLE;

CREATE OR REPLACE FUNCTION actor.org_unit_common_ancestors ( INT, INT ) RETURNS SETOF actor.org_unit AS $$
	SELECT	*
	  FROM	actor.org_unit_ancestors($1)
			INTERSECT
	SELECT	*
	  FROM	actor.org_unit_ancestors($2);
$$ LANGUAGE SQL STABLE;

CREATE OR REPLACE FUNCTION actor.org_unit_proximity ( INT, INT ) RETURNS INT AS $$
	SELECT COUNT(id)::INT FROM (
		SELECT id FROM actor.org_unit_combined_ancestors($1, $2)
			EXCEPT
		SELECT id FROM actor.org_unit_common_ancestors($1, $2)
	) z;
$$ LANGUAGE SQL STABLE;

CREATE OR REPLACE FUNCTION actor.org_unit_ancestor_setting( setting_name TEXT, org_id INT ) RETURNS SETOF actor.org_unit_setting AS $$
DECLARE
    setting RECORD;
    cur_org INT;
BEGIN
    cur_org := org_id;
    LOOP
        SELECT INTO setting * FROM actor.org_unit_setting WHERE org_unit = cur_org AND name = setting_name;
        IF FOUND THEN
            RETURN NEXT setting;
        END IF;
        SELECT INTO cur_org parent_ou FROM actor.org_unit WHERE id = cur_org;
        EXIT WHEN cur_org IS NULL;
    END LOOP;
    RETURN;
END;
$$ LANGUAGE plpgsql STABLE;

COMMENT ON FUNCTION actor.org_unit_ancestor_setting( TEXT, INT) IS $$
/**
* Search "up" the org_unit tree until we find the first occurrence of an 
* org_unit_setting with the given name.
*/
$$;

-- Intended to be used in a unique index on authority.record_entry like so:
-- CREATE UNIQUE INDEX unique_by_heading_and_thesaurus
--   ON authority.record_entry (authority.normalize_heading(marc))
--   WHERE deleted IS FALSE or deleted = FALSE;
CREATE OR REPLACE FUNCTION authority.normalize_heading( TEXT ) RETURNS TEXT AS $func$
    use strict;
    use warnings;

    use utf8;
    use MARC::Record;
    use MARC::File::XML (BinaryEncoding => 'UTF8');
    use UUID::Tiny ':std';

    my $xml = shift() or return undef;

    my $r;

    # Prevent errors in XML parsing from blowing out ungracefully
    eval {
        $r = MARC::Record->new_from_xml( $xml );
        1;
    } or do {
       return 'BAD_MARCXML_' . create_uuid_as_string(UUID_MD5, $xml);
    };

    if (!$r) {
       return 'BAD_MARCXML_' . create_uuid_as_string(UUID_MD5, $xml);
    }

    # From http://www.loc.gov/standards/sourcelist/subject.html
    my $thes_code_map = {
        a => 'lcsh',
        b => 'lcshac',
        c => 'mesh',
        d => 'nal',
        k => 'cash',
        n => 'notapplicable',
        r => 'aat',
        s => 'sears',
        v => 'rvm',
    };

    # Default to "No attempt to code" if the leader is horribly broken
    my $fixed_field = $r->field('008');
    my $thes_char = '|';
    if ($fixed_field) { 
        $thes_char = substr($fixed_field->data(), 11, 1) || '|';
    }

    my $thes_code = 'UNDEFINED';

    if ($thes_char eq 'z') {
        # Grab the 040 $f per http://www.loc.gov/marc/authority/ad040.html
        $thes_code = $r->subfield('040', 'f') || 'UNDEFINED';
    } elsif ($thes_code_map->{$thes_char}) {
        $thes_code = $thes_code_map->{$thes_char};
    }

    my $auth_txt = '';
    my $head = $r->field('1..');
    if ($head) {
        # Concatenate all of these subfields together, prefixed by their code
        # to prevent collisions along the lines of "Fiction, North Carolina"
        foreach my $sf ($head->subfields()) {
            $auth_txt .= '‡' . $sf->[0] . ' ' . $sf->[1];
        }
    }
    
    # Perhaps better to parameterize the spi and pass as a parameter
    $auth_txt =~ s/'//go;

    if ($auth_txt) {
        my $result = spi_exec_query("SELECT public.naco_normalize('$auth_txt') AS norm_text");
        my $norm_txt = $result->{rows}[0]->{norm_text};
        return $head->tag() . "_" . $thes_code . " " . $norm_txt;
    }

    return 'NOHEADING_' . $thes_code . ' ' . create_uuid_as_string(UUID_MD5, $xml);
$func$ LANGUAGE 'plperlu' IMMUTABLE;

COMMENT ON FUNCTION authority.normalize_heading( TEXT ) IS $$
/**
* Extract the authority heading, thesaurus, and NACO-normalized values
* from an authority record. The primary purpose is to build a unique
* index to defend against duplicated authority records from the same
* thesaurus.
*/
$$;
