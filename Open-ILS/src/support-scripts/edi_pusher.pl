#!/usr/bin/perl
# ---------------------------------------------------------------
# Copyright (C) 2010 Equinox Software, Inc
# Author: Joe Atzberger <jatzberger@esilibrary.com>
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

use Data::Dumper;
use vars qw/$debug/;

use OpenILS::Utils::CStoreEditor;   # needs init() after IDL is loaded (by Cronscript session)
use OpenILS::Utils::Cronscript;
use OpenILS::Utils::Fieldmapper;
use OpenILS::Application::AppUtils;
use OpenILS::Application::Acq::EDI;
use OpenILS::Application::Acq::EDI::Translator;

INIT {
    $debug = 1;
}

OpenILS::Utils::Cronscript->new()->session('open-ils.acq') or die "No session created";
OpenILS::Utils::CStoreEditor::init();

sub editor {
    my $ed = OpenILS::Utils::CStoreEditor->new(@_) or die "Failed to get new CStoreEditor";
    return $ed;
}

my $e = editor();
my $hook = 'format.po.jedi';
my $defs = $e->search_action_trigger_event_definition({hook => $hook});

# print Dumper($defs);
print "\nHook '$hook' is used in ", scalar(@$defs), " event definition(s):\n";

$Data::Dumper::Indent = 1;
my $trans = OpenILS::Application::Acq::EDI::Translator->new();
foreach my $def (@$defs) {
    printf "%3s - '%s'\n", $def->id, $def->name;
    my $events = $e->search_action_trigger_event([
        {event_def => $def->id},
        {flesh => 1, flesh_fields => { atev => ['template_output'] }}
    ]);
    print "Event definition ", $def->id, " has ", scalar(@$events), " events\n";
    foreach (@$events) {
        my $message = Fieldmapper::acq::edi_message->new;
        print "Event ", $_->id, " targets PO ", $_->target, ":\n";
        print Dumper($_), "\n";
        my $target = $e->retrieve_acq_purchase_order([
            $_->target, {
                flesh => 2,
                flesh_fields => {
                    acqpo  => ['provider'],
                    acqpro => ['edi_default'],
                },
            }
        ]);
        print "Target: ", Dumper($target), "\n";
        my $logstr = sprintf "provider %s (%s)", $target->provider->id, $target->provider->name;
        unless ($target->provider->edi_default and $message->account($target->provider->edi_default->id)) {
            printf STDERR "ERROR: No edi_default account found for $logstr.  File will not be sent!\n";
        }
        my $edi = $trans->json2edi($_->template_output()->data);   #  Going underneath EDI.pm
        print "\n\ntranslator output: ", Dumper($edi), "\n";
        $message->jedi($_->template_output()->data);
        print "\ntarget->provider->edi_default->id: ", $target->provider->edi_default->id, "\n";
        print "\nNow calling attempt_translation\n\n";
        unless (OpenILS::Application::Acq::EDI->attempt_translation($message, 1)) {
            print STDERR "ERROR: attempt_translation failed, skipping message\n";
            next;
            # The premise here is that if the translator failed, it is better to try again later from a "fresh" fetched file
            # than to add a cascade of failing inscrutable copies of the same message(s) to our DB.  
        }
        print "Writing new message + translation in to DB\n";
        $e->xact_begin;
        $e->create_acq_edi_message($message) or warn "create_acq_edi_message failed!  $!";
        $e->xact_commit;

        print "Calling send_core(...)\n";
        if (OpenILS::Application::Acq::EDI->send_core($target->provider->edi_default, [$message])) {
            print "\tSent message ", $message->id, "\n";
        } else {
            print STDERR "ERROR: send_core failed for message ", $message->id, "\n";
        }
    }
}

print "\ndone\n";
