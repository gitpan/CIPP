#!/usr/local/bin/perl
#==============================================================================
#
# MODUL
#	CIPP::OutputHandle
#
# METHODEN
#	$OutputHandle = new CIPP::OutputHandle ($output);
#		$output		Dateiname, Filehandle-Referenz oder
#				Scalar-Referenz (Memory-Modus)
#
#		Oeffnet Datei bzw. initialisert das Objekt zum Schreiben
#		in den evtl. uebergebenen Buffer (Memory-Modus), der Buffer
#		wird nicht geleert, anhaengen ist also moeglich
#
#	$error = $OutputHandle->Get_Init_Status();
#		liefert	0 : Fehler beim Initialisieren
#			1 : OK
#
#	$ok = $OutputHandle->Write($chunk);
#		Schreibt in das Datenziel
#		liefert 0 : Fehler beim Schreiben
#			1 : OK
#
# INTERNE VARIABLEN
#	$filehandle	Enthaelt Referenz auf das Filehandle, undef wenn
#			Schreiben in den Speicher
#	$buffer_ref	Referenz auf Schreibpuffer, wenn im Memory-Modus
#	$init_status	0 : Fehler beim Initilisieren
#			1 : OK
#	
#==============================================================================
#
# COPYRIGHT
#	(c) 1997 dimedis GmbH, All Rights Reserved
#
#------------------------------------------------------------------------------
#
# MODIFICATION HISTORY
#	25.09.97 0.1.0.0 joern
#		Design des Moduls und Implementation folgender Methoden
#		- Konstruktor
#		- Destruktor
#		- Get_Init_Status
#		- Write
#
#	30.09.97 0.1.0.1 joern
#		- Implementation der Methoden
#
#	02.10.97 0.1.0.2 joern
#		- Package-Variable $obj_nr eingefuehrt, die fuer jede
#		  neue Instanz erhoeht wird. Wird dazu benutzt, eindeutige
#		  Filehandles zu generieren, sonst koennen nicht mehrere
#		  Instanzen gleichzeitig benutzt werden
#
#	16.01.1999 0.2.0.0 joern
#		+ umbenannt von OutputHandle nach CIPP::OutputHandle

#==============================================================================

if ( 0 ) {
	print "Testlauf:\n\n";

	print "Schreibe in Datei mit dem Namen 'testdatei1.txt'...\n";
	$h1 = new CIPP::OutputHandle ('testdatei1.txt');
	print "Status: ", $h1->Get_Init_Status(),"\n";
	$h1->Write ("das ist ein Test 1\n");
	$h1->Write ("das war's auch schon\n");
	$h1 = undef;

	print "\nSchreibe ueber Handle in Datei 'testdatei2.txt'...\n";
	open (RAUS, "> testdatei2.txt") or die;
	$h2 = new CIPP::OutputHandle (\*RAUS);
	print "Status: ", $h2->Get_Init_Status(),"\n";
	$h2->Write ("das ist ein Test 2\n");
	$h2->Write ("das war's auch schon\n");
	$h2 = undef;

	print "\nSchreibe in Memory...\n";
	my $memory = '';
	$h3 = new CIPP::OutputHandle (\$memory);
	print "Status: ", $h3->Get_Init_Status(),"\n";
	$h3->Write ("das ist ein Test 3\n");
	$h3->Write ("das war's auch schon\n");
	$h3 = undef;

	print "Im Memory steht:\n$memory\n";
	exit;
}

package CIPP::OutputHandle;

$CIPP::OutputHandle::obj_nr = 0;

sub new {
	my $type = shift;
	my ($output) = @_;

	my $init_status = 1;
	my $filehandle;
	my $buffer;

	$CIPP::OutputHandle::obj_nr++;

	if ( ref $output eq 'GLOB' ) {
		$buffer_ref = undef;
		$filehandle = $output;
		my $test_filehandle = print $filehandle '';
		$init_status = 0 if ! defined $test_filehandle;
	} elsif ( ref $output eq 'SCALAR' ) {
		$filehandle = undef;
		$buffer_ref = $output;
	} elsif (not ref $output ) {
		$filehandle = "OutputHandle".$CIPP::OutputHandle::obj_nr;
		open ($filehandle, "> $output") || ($init_status=0);
		$buffer_ref = undef;
	} else {
		$filehandle = undef;
		$buffer_ref = undef;
		$init_status = 0;
	}

	my $self = {
		"filehandle" => $filehandle,
		"buffer_ref" => $buffer_ref,
		"init_status" => $init_status,
		"obj_nr" => $CIPP::OutputHandle::obj_nr
	};

	return bless $self, $type;
}

sub DESTROY {
	my $self = shift;

	if ( defined $self->{filehandle} ) {
		my $filehandle = $self->{filehandle};
		close $filehandle;
	}
}

sub Get_Init_Status {
	my $self = shift;
	return $self->{init_status};
}

sub Write {
	my $self = shift;
	return undef if ! $self->{init_status};

	my ($output) = @_;

	if ( defined $self->{filehandle} ) {
		my $filehandle = $self->{filehandle};
		return print $filehandle $output;
	} else {
		${$self->{buffer_ref}} .= $output;
		return 1;
	}
}

1;
