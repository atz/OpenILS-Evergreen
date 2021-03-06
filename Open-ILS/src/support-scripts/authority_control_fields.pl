#!/usr/bin/perl
# Copyright (C) 2010 Laurentian University
# Author: Dan Scott <dscott@laurentian.ca>
#
# This program is free software; you can redistribute it and/or
# modify it under the terms of the GNU General Public License
# as published by the Free Software Foundation; either version 2
# of the License, or (at your option) any later version.

# This program is distributed in the hope that it will be useful,
# but WITHOUT ANY WARRANTY; without even the implied warranty of
# MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
# GNU General Public License for more details.
# ---------------------------------------------------------------

use strict;
use warnings;
use DBI;
use Getopt::Long;
use MARC::Record;
use MARC::File::XML;
use OpenSRF::System;
use OpenILS::Utils::Fieldmapper;
use OpenSRF::Utils::SettingsClient;
use Encode;
use Unicode::Normalize;
use OpenILS::Application::AppUtils;
use Data::Dumper;

=head1

For a given set of records (specified by ID at the command line, or special option --all):

=over

=item * Iterate through the list of fields that are controlled fields

=item * Iterate through the list of subfields that are controlled for
that given field

=item * Search for a matching authority record for that combination of
field + subfield(s)

=over

=item * If we find a match, then add a $0 subfield to that field identifying
the controlling authority record

=item * If we do not find a match, then insert a row into an "uncontrolled"
table identifying the record ID, field, and subfield(s) that were not controlled

=back

=item * Iterate through the list of floating subdivisions

=over

=item * If we find a match, then add a $0 subfield to that field identifying
the controlling authority record

=item * If we do not find a match, then insert a row into an "uncontrolled"
table identifying the record ID, field, and subfield(s) that were not controlled

=back

=item * If we changed the record, update it in the database

=back

=cut

my $all_records;
my $bootstrap = '/openils/conf/opensrf_core.xml';
my @records;
my $result = GetOptions(
    'configuration=s' => \$bootstrap,
    'record=s' => \@records,
    'all' => \$all_records
);

OpenSRF::System->bootstrap_client(config_file => $bootstrap);
Fieldmapper->import(IDL => OpenSRF::Utils::SettingsClient->new->config_value("IDL"));

# must be loaded and initialized after the IDL is parsed
use OpenILS::Utils::CStoreEditor;
OpenILS::Utils::CStoreEditor::init();

my $editor = OpenILS::Utils::CStoreEditor->new;
my $undeleted;
if ($all_records) {
    # get a list of all non-deleted records from Evergreen
    # open-ils.cstore open-ils.cstore.direct.biblio.record_entry.id_list.atomic {"deleted":"f"}
    $undeleted = $editor->request( 
        'open-ils.cstore.direct.biblio.record_entry.id_list.atomic', 
        [{deleted => 'f'}, {id => { '>' => 0}}]
    );
    @records = @$undeleted;
}
# print Dumper($undeleted, \@records);

# Hash of controlled fields & subfields in bibliographic records, and their
# corresponding controlling fields & subfields in the authority record
#
# So, if the bib 650$a can be controlled by an auth 150$a, that maps to:
# 650 => { a => { 150 => 'a'}}
my %controllees = (
    100 => { a => { 100 => 'a' },
             b => { 100 => 'b' },
             c => { 100 => 'c' },
             d => { 100 => 'd' },
             e => { 100 => 'e' },
             f => { 100 => 'f' },
             g => { 100 => 'g' },
             j => { 100 => 'j' },
             k => { 100 => 'k' },
             l => { 100 => 'l' },
             n => { 100 => 'n' },
             p => { 100 => 'p' },
             q => { 100 => 'q' },
             t => { 100 => 't' },
             u => { 100 => 'u' },
             4 => { 100 => '4' },
    },
    110 => { a => { 110 => 'a' },
             b => { 110 => 'b' },
             c => { 110 => 'c' },
             d => { 110 => 'd' },
             e => { 110 => 'e' },
             f => { 110 => 'f' },
             g => { 110 => 'g' },
             k => { 110 => 'k' },
             l => { 110 => 'l' },
             n => { 110 => 'n' },
             p => { 110 => 'p' },
             t => { 110 => 't' },
             u => { 110 => 'u' },
             4 => { 110 => '4' },
    },
    111 => { a => { 111 => 'a' },
             c => { 111 => 'c' },
             d => { 111 => 'd' },
             e => { 111 => 'e' },
             f => { 111 => 'f' },
             g => { 111 => 'g' },
             j => { 111 => 'j' },
             k => { 111 => 'k' },
             l => { 111 => 'l' },
             n => { 111 => 'n' },
             p => { 111 => 'p' },
             q => { 111 => 'q' },
             t => { 111 => 't' },
             u => { 111 => 'u' },
             4 => { 111 => '4' },
    },
    130 => { a => { 130 => 'a' },
             d => { 130 => 'd' },
             f => { 130 => 'f' },
             g => { 130 => 'g' },
             h => { 130 => 'h' },
             k => { 130 => 'k' },
             l => { 130 => 'l' },
             m => { 130 => 'm' },
             n => { 130 => 'n' },
             o => { 130 => 'o' },
             p => { 130 => 'p' },
             r => { 130 => 'r' },
             s => { 130 => 's' },
             t => { 130 => 't' },
    },
    600 => { a => { 100 => 'a' },
             b => { 100 => 'b' },
             c => { 100 => 'c' },
             d => { 100 => 'd' },
             e => { 100 => 'e' },
             f => { 100 => 'f' },
             g => { 100 => 'g' },
             h => { 100 => 'h' },
             j => { 100 => 'j' },
             k => { 100 => 'k' },
             l => { 100 => 'l' },
             m => { 100 => 'm' },
             n => { 100 => 'n' },
             o => { 100 => 'o' },
             p => { 100 => 'p' },
             q => { 100 => 'q' },
             r => { 100 => 'r' },
             s => { 100 => 's' },
             t => { 100 => 't' },
             v => { 100 => 'v' },
             x => { 100 => 'x' },
             y => { 100 => 'y' },
             z => { 100 => 'z' },
             4 => { 100 => '4' },
    },
    610 => { a => { 110 => 'a' },
             b => { 110 => 'b' },
             c => { 110 => 'c' },
             d => { 110 => 'd' },
             e => { 110 => 'e' },
             f => { 110 => 'f' },
             g => { 110 => 'g' },
             h => { 110 => 'h' },
             k => { 110 => 'k' },
             l => { 110 => 'l' },
             m => { 110 => 'm' },
             n => { 110 => 'n' },
             o => { 110 => 'o' },
             p => { 110 => 'p' },
             r => { 110 => 'r' },
             s => { 110 => 's' },
             t => { 110 => 't' },
             v => { 110 => 'v' },
             x => { 110 => 'x' },
             y => { 110 => 'y' },
             z => { 110 => 'z' },
    },
    611 => { a => { 111 => 'a' },
             c => { 111 => 'c' },
             d => { 111 => 'd' },
             e => { 111 => 'e' },
             f => { 111 => 'f' },
             g => { 111 => 'g' },
             h => { 111 => 'h' },
             j => { 111 => 'j' },
             k => { 111 => 'k' },
             l => { 111 => 'l' },
             n => { 111 => 'n' },
             p => { 111 => 'p' },
             q => { 111 => 'q' },
             s => { 111 => 's' },
             t => { 111 => 't' },
             v => { 111 => 'v' },
             x => { 111 => 'x' },
             y => { 111 => 'y' },
             z => { 111 => 'z' },
    },
    630 => { a => { 130 => 'a' },
             d => { 130 => 'd' },
             f => { 130 => 'f' },
             g => { 130 => 'g' },
             h => { 130 => 'h' },
             k => { 130 => 'k' },
             l => { 130 => 'l' },
             m => { 130 => 'm' },
             n => { 130 => 'n' },
             o => { 130 => 'o' },
             p => { 130 => 'p' },
             r => { 130 => 'r' },
             s => { 130 => 's' },
             t => { 130 => 't' },
             v => { 130 => 'v' },
             x => { 130 => 'x' },
             y => { 130 => 'y' },
             z => { 130 => 'z' },
    },
    648 => { a => { 148 => 'a' },
             v => { 148 => 'v' },
             x => { 148 => 'x' },
             y => { 148 => 'y' },
             z => { 148 => 'z' },
    },
    650 => { a => { 150 => 'a' },
             b => { 150 => 'b' },
             v => { 150 => 'v' },
             x => { 150 => 'x' },
             y => { 150 => 'y' },
             z => { 150 => 'z' },
    },
    651 => { a => { 151 => 'a' },
             v => { 151 => 'v' },
             x => { 151 => 'x' },
             y => { 151 => 'y' },
             z => { 151 => 'z' },
    },
    655 => { a => { 155 => 'a' },
             v => { 155 => 'v' },
             x => { 155 => 'x' },
             y => { 155 => 'y' },
             z => { 155 => 'z' },
    },
    700 => { a => { 100 => 'a' },
             b => { 100 => 'b' },
             c => { 100 => 'c' },
             d => { 100 => 'd' },
             e => { 100 => 'e' },
             f => { 100 => 'f' },
             g => { 100 => 'g' },
             j => { 100 => 'j' },
             k => { 100 => 'k' },
             l => { 100 => 'l' },
             n => { 100 => 'n' },
             p => { 100 => 'p' },
             q => { 100 => 'q' },
             t => { 100 => 't' },
             u => { 100 => 'u' },
             4 => { 100 => '4' },
    },
    710 => { a => { 110 => 'a' },
             b => { 110 => 'b' },
             c => { 110 => 'c' },
             d => { 110 => 'd' },
             e => { 110 => 'e' },
             f => { 110 => 'f' },
             g => { 110 => 'g' },
             k => { 110 => 'k' },
             l => { 110 => 'l' },
             n => { 110 => 'n' },
             p => { 110 => 'p' },
             t => { 110 => 't' },
             u => { 110 => 'u' },
             4 => { 110 => '4' },
    },
    711 => { a => { 111 => 'a' },
             c => { 111 => 'c' },
             d => { 111 => 'd' },
             e => { 111 => 'e' },
             f => { 111 => 'f' },
             g => { 111 => 'g' },
             j => { 111 => 'j' },
             k => { 111 => 'k' },
             l => { 111 => 'l' },
             n => { 111 => 'n' },
             p => { 111 => 'p' },
             q => { 111 => 'q' },
             t => { 111 => 't' },
             u => { 111 => 'u' },
             4 => { 111 => '4' },
    },
    730 => { a => { 130 => 'a' },
             d => { 130 => 'd' },
             f => { 130 => 'f' },
             g => { 130 => 'g' },
             h => { 130 => 'h' },
             k => { 130 => 'k' },
             l => { 130 => 'l' },
             m => { 130 => 'm' },
             n => { 130 => 'n' },
             o => { 130 => 'o' },
             p => { 130 => 'p' },
             r => { 130 => 'r' },
             s => { 130 => 's' },
             t => { 130 => 't' },
    },
    751 => { a => { 151 => 'a' },
             v => { 151 => 'v' },
             x => { 151 => 'x' },
             y => { 151 => 'y' },
             z => { 151 => 'z' },
    },
);

foreach my $rec_id (@records) {
    # print "$rec_id\n";

    my $e = OpenILS::Utils::CStoreEditor->new(xact=>1);
    # State variable; was the record changed?
    my $changed;

    # get the record
    my $record = $e->retrieve_biblio_record_entry($rec_id);
    next unless $record;
    # print Dumper($record);

    my $marc = MARC::Record->new_from_xml($record->marc());

    # get the list of controlled fields
    my @c_fields = keys %controllees;

    foreach my $c_tag (@c_fields) {
        my @c_subfields = keys %{$controllees{"$c_tag"}};
        # print "Field: $field subfields: ";
        # foreach (@subfields) { print "$_ "; }

        # Get the MARCXML from the record and check for controlled fields/subfields
        my @bib_fields = ($marc->field($c_tag));
        foreach my $bib_field (@bib_fields) {
            # print $_->as_formatted(); 
            my %match_subfields;
            my $match_tag;
            my @searches;
            foreach my $c_subfield (@c_subfields) {
                my $sf = $bib_field->subfield($c_subfield);
                if ($sf) {
                    # Give me the first element of the list of authority controlling tags for this subfield
                    # XXX Will we need to support more than one controlling tag per subfield? Probably. That
                    # will suck. Oh well, leave that up to Ole to implement.
                    $match_subfields{$c_subfield} = (keys %{$controllees{$c_tag}{$c_subfield}})[0];
                    $match_tag = $match_subfields{$c_subfield};
                    push @searches, {term => $sf, subfield => $c_subfield};
                }
            }
            # print Dumper(\%match_subfields);
            next if !$match_tag;

            my @tags = ($match_tag);

            # print "Controlling tag: $c_tag and match tag $match_tag\n";
            # print Dumper(\@tags, \@searches);

            # Now we've built up a complete set of matching controlled
            # subfields for this particular field; let's check to see if
            # we have a matching authority record
            my $session = OpenSRF::AppSession->create("open-ils.search");
            my $validates = $session->request("open-ils.search.authority.validate.tag.id_list", 
                "tags", \@tags, "searches", \@searches
            )->gather();
            $session->disconnect();

            # print Dumper($validates);

            if (scalar(@$validates) == 0) {
                next;
            }

            # Iterate through the returned authority record IDs to delete any
            # matching $0 subfields already in the bib record
            foreach my $auth_zero (@$validates) {
                $bib_field->delete_subfield(code => '0', match => qr/\)$auth_zero$/);
            }

            # Okay, we have a matching authority control; time to
            # add the magical subfield 0. Use the first returned auth
            # record as a match.
            my $auth_id = @$validates[0];
            my $auth_rec = $e->retrieve_authority_record_entry($auth_id);
            my $auth_marc = MARC::Record->new_from_xml($auth_rec->marc());
            my $cni = $auth_marc->field('003')->data();
            
            $bib_field->add_subfields('0' => "($cni)$auth_id");
            $changed = 1;
        }
    }
    if ($changed) {
        # print $marc->as_formatted();
        my $xml = $marc->as_xml_record();
        $xml =~ s/\n//sgo;
        $xml =~ s/^<\?xml.+\?\s*>//go;
        $xml =~ s/>\s+</></go;
        $xml =~ s/\p{Cc}//go;
        $xml = OpenILS::Application::AppUtils->entityize($xml);

        $record->marc($xml);
        $e->update_biblio_record_entry($record);
    }
    $e->commit();
}
