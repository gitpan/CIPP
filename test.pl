#!/usr/local/bin/perl

BEGIN { $| = 1; print "1..1\n"; }
END {print "not ok 1\n" unless $loaded;}
use CIPP;
$loaded = 1;
print "ok 1\n";

use strict;

my $source = "test.cipp";
my $target = "test.cgi";
my $orig = "output.cgi";
my $project_hash = undef;
my $database_hash = {
	"zyn" => "CIPP_DB_DBI"
};
my $mime_type = "text/html";
my $default_db = "zyn";
my $call_path = "input.cipp";
my $skip_header_line = undef;
my $debugging = 1;
my $result_type = "cipp";
my $use_strict = 1;
my $reintrant = 1;
my $apache_mod = 1;

my $CIPP = new CIPP (
	$source, $target, $project_hash, $database_hash, $mime_type,
	$default_db, $call_path, $skip_header_line, $debugging,
	$result_type, $use_strict, $reintrant, $apache_mod
);
$CIPP->Preprocess;

if ( not $CIPP->Get_Preprocess_Status ) {
	print "errors:\n";
	my $aref = $CIPP->Get_Messages;
	my $msg;
	foreach $msg (@{$aref}) {
		print $msg, "\n\n";
	}
}

$CIPP = undef;

open (ORIG, $orig) or die "can't read $orig";
open (GEN, $target) or die "can't read $target";

my $orig_cgi = join ('', <ORIG>);
my $gen_cgi  = join ('', <GEN>);

close ORIG;
close GEN;

$orig_cgi =~ s/\r//g;
$gen_cgi =~ s/\r//g;

print ($orig_cgi eq $gen_cgi ? 'ok' : 'not ok');
print " 2\n";

