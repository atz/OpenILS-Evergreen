#/usr/bin/perl
use strict; use warnings;
use lib q|../../../perlmods/|;
use Time::HiRes qw/time/;
use OpenILS::Application::Circ::ScriptBuilder;
require '../oils_header.pl';
use vars qw/ $user $authtoken $apputils /;

# ---------------------------------------------------------------------
# SCRIPT VARS
# ----------------------------------------------------------------------
#my $patronid					= 3;
my $patronid					= 1000502;
my $copyid						= 8000107;
my $patron_items_out			= 11;
my $patron_overdue_count	= 11;
my $patron_fines				= 20;

# these are not currently tested in the scripts
my $is_renewal					= 0;
my $is_non_cat					= 0;
my $is_hold						= 0;
my $non_cat_type				= 1;
# ---------------------------------------------------------------------



my $bsconfig = shift;
my $script = shift;

die "$0: <bootstrap> <absolute_script_path>\n" unless $script;

my $path;

($path, $script) = ($script =~ m#(/.*/)(.*)#);
osrf_connect($bsconfig);

my $s = time;
my $runner = OpenILS::Application::Circ::ScriptBuilder->build(
	{
		copy_id						=> $copyid,
		patron_id					=> $patronid,
		fetch_patron_circ_info	=> 1,
		flesh_age_protect			=> 1,
		_direct						=> {
			isNonCat		=> $is_non_cat,
			isRenewal	=> $is_renewal,
			nonCatType	=> $non_cat_type,
		}
	}
);


# ---------------------------------------------------------------------
# Override the default log functions for convenience
# ---------------------------------------------------------------------
$runner->insert(log_activity	=> sub { print "@_\n"; return 1;} );
$runner->insert(log_error		=> sub { print "@_\n"; return 1;} );
$runner->insert(log_warn		=> sub { print "@_\n"; return 1;} );
$runner->insert(log_info		=> sub { print "@_\n"; return 1;} );
$runner->insert(log_debug		=> sub { print "@_\n"; return 1;} );
$runner->insert(log_internal	=> sub { print "@_\n"; return 1;} );


#$runner->add_path('/openils/var/web/opac/common/js');
$runner->add_path($path);
$runner->add_path("$path/../");
#$runner->add_path("$path/../catalog/");


# ---------------------------------------------------------------------
# Run the script
# ---------------------------------------------------------------------
print "\nLoading script: $script\n";
print "\n" . '-'x70 . "\n";

$runner->load($script);
my $result = $runner->run or die "Script died: $@";

my $end = time - $s;


# ---------------------------------------------------------------------
# Print out any events that occurred
# ---------------------------------------------------------------------
print "\n" . '-'x70 . "\n";

my $events = $result->{events};
my $ievents = $result->{infoEvents};
my $fevents = $result->{fatalEvents};

print "events = @$events\n";
print "info events = @$ievents\n";
print "fatal events = @$fevents\n";

print "\ntime = $end\n";

sub show_events {
	my $t = shift;
	my $e = shift;
	my @e;

	if($e and @e = split(/,/, $e)) {
		print "$t : $_\n" for @e;

	} else {
		print "No $t occurred\n";
	} 
}

print "\n";




