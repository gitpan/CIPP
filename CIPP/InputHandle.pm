#!/usr/local/bin/perl
#==============================================================================
#
# MODUL
#	CIPP::InputHandle
#
# METHODEN
#	$InputHandle = new CIPP::InputHandle ($input);
#		$input		Dateiname, Filehandle-Referenz oder
#				Scalar-Referenz
#
#		Oeffnet Datei bzw. initialisert das Objekt zum Lesen
#		aus dem evtl. uebergebenen Buffer (Scalar-Referenz)
#
#	$error = $InputHandle->Get_Init_Status();
#		liefert	0 : Fehler beim Initialisieren
#			1 : OK
#
#	$line = $InputHandle->Read();
#		Gibt Zeile aus Datenquelle zurueck, undefiniert wenn EOF
#
#	$chunk = $InputHandle->Read_Cond($magic, $with_escaping);
#		Liest aus Datenquelle, bis $magic gefunden, und gibt gelesene
#		Daten inklusive $magic zurueck. Wenn $with_escaping gesetzt
#		ist, werden $magic mit vorstehendem \ bei der Suche ignoriert.
#		Die \ werden NICHT aus dem Rueckgabewert entfernt!
#
#	$chunk = $InputHandle->Read_Cond_Quoted($magic,$quote_char);
#		Liest aus Datenquelle, bis $magic gefunden, wobei Vorkommen
#		von $magic innerhalb von zwei $quote_char's ignoriert
#		werden. Escapen von Quotes via \ ist moeglich. Die \ werden
#		NICHT aus dem Rueckgabewert entfernt!
#
#	$InputHandle->Add_To_Buffer($chunk);
#		Fügt $chunk vor dem aktuellen Lesebuffer ein
#
#	$InputHandle->Set_Comment_Filter($on);
#		Schaltet Kommentarfilter fuer Dateiinput ein, wenn $on true.
#		Von nun an wird jede Zeile, die mit \s*# anfaengt ignoriert,
#		wenn aus einer Datei gelesen wird
#
#	$InputHandle->Get_Line_Number();
#		Gibt aktuelle Zeilennummer beim Lesen aus Datei aus
#
#
# INTERNE VARIABLEN
#	$filehandle	Enthaelt Referenz auf das Filehandle, undef wenn
#			Lesen aus Speicher
#	$buffer		Lesepuffer
#	$init_status	0 : Fehler beim Initilisieren
#			1 : OK
#	$comment_filter	0 : Kommentare werden belassen
#			1 : Kommentare werden gefiltert
#	$line		Aktuelle Zeilennummer beim Lesen aus Datei
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
#		- Read
#		- Read_Cond
#		- Read_Cond_Quoted
#		- Add_To_Buffer
#
#	29.09.97 0.1.0.1 joern
#		- Read_Cond um die Möglichkeit erweitert, daß via \ escape'te
#		  Magics ignoriert werden
#
#	30.09.97 0.1.0.2 joern
#		- Set_Comment_Filter ($on) hinzugefuegt
#		- Read() ueberlist nun ggf. Kommentare
#		- Get_Line_Number() hinzugefügt
#		- Zeilennummern werden nachgehalten
#
#	02.10.97 0.1.0.3 joern
#		- Package-Variable $obj_nr eingefuehrt, die fuer jede
#		  neue Instanz erhoeht wird. Wird dazu benutzt, eindeutige
#		  Filehandles zu generieren, sonst koennen nicht mehrere
#		  Instanzen gleichzeitig benutzt werden
#
#	15.09.98 0.1.0.4 joern
#		- Als Input-Quelle kann beim Konstruktor auch eine
#		  FileHandle Referenz übergeben werden (anstelle des GLOB's)
#
#	16.01.1999 0.2.0.0 joern
#		+ umbenannt von InputHandle nach CIPP::InputHandle
#
#==============================================================================

if ( 0 ) {
	print "Datei ausgeben!\n";
	$h1 = new CIPP::InputHandle ("testdatei");
	while ( $line = $h1->Read() ) {
		print $line;
	}
	$h1 = undef;

	print "\n\nSuchen:\n";

	$h2 = new CIPP::InputHandle ("testdatei");
	print "Status: ", $h2->Get_Init_Status(), "\n";

	while ( $chunk = $h2->Read_Cond('"',1) ) {
		print "GOT {$chunk}\n\n";
	}

	exit;
}

			
package CIPP::InputHandle;

$CIPP::InputHandle::obj_nr = 0;
$VERSION = "0.2";

sub new {
	my $type = shift;
	my ($input) = @_;

	my $init_status = 1;
	my $filehandle;
	my $buffer;
	
	$CIPP::InputHandle::obj_nr++;

	if ( ref $input eq 'GLOB' or ref $input eq 'FileHandle' ) {
		$filehandle = $input;
	} elsif ( ref $input eq 'SCALAR' ) {
		$filehandle = undef;
		$buffer = $$input;
	} elsif (not ref $input) {
		$filehandle = "InputHandle".$CIPP::InputHandle::obj_nr;
#		print "FILEHANDLE = $filehandle\n";
		open ($filehandle, $input) || ($init_status=0);
	} else {
		$filehandle = undef;
		$init_status = 0;
	}

	$buffer = '' if !defined $buffer;

	my $self = {
		"filehandle" => $filehandle,
		"buffer" => $buffer,
		"init_status" => $init_status,
		"comment_filter" => 0,
		"line" => 0,
		"obj_nr" => $CIPP::InputHandle::obj_nr
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

sub Read {
	my $self = shift;
	return undef if ! $self->{init_status};

	my $result;

	if ( $self->{buffer} ne '' ) {
		$self->{buffer} =~ s/^([^\n]*)//;
		$result = $1;
		if ( $self->{buffer} =~ s/^\n// ) {
			return "$result\n";
		} else {
			return $result;
		}
	}

	if ( defined $self->{filehandle} ) {
		my $filehandle = $self->{filehandle};
		my $line;
		if ( ! $self->{comment_filter} ) {
			$line = scalar (<$filehandle>);
			++$self->{line} if defined $line;
			$line =~ s/\r//g;
			return $line;
		}

		do {
			$line = scalar (<$filehandle>);
			++$self->{line} if defined $line;
			$line =~ s/\r//g;
		} while ( !eof($filehandle) && $line =~ /^\s*#/ );

		if ( defined $line && $line =~ /^\s*#/ ) {
			return undef;
		} else {
			return $line;
		}
	}

	return undef;
}

sub Add_To_Buffer {
	my $self = shift;
	return undef if ! $self->{init_status};

	my ($chunk) = @_;

	$self->{buffer} = $chunk.$self->{buffer};

	return 1;
}

sub Get_Init_Status {
	my $self = shift;
	return $self->{init_status};
}

sub Read_Cond {
	my $self = shift;
	return undef if ! $self->{init_status};

	my ($magic, $with_escaping) = @_;	
	my $buffer = '';
	my ($line, $pos);
	my $startpos = 0;

	while ( $line = $self->Read() ) {
		$buffer .= $line;
		if ( -1 != ($pos = index ($buffer, $magic, $startpos)) ) {
			# ist $magic escaped?
			if ( $with_escaping && $pos != 0 &&
			     substr($buffer,$pos-1,1) eq "\\" ) {
				$startpos = $pos + length($magic);
			} else {
				$self->Add_To_Buffer
					(substr $buffer, $pos+length($magic));
				return substr ($buffer, 0, $pos+length($magic));
			}
		} else {
			$startpos = length($buffer);
		}
	}

	return $buffer;
}

sub Read_Cond_Quoted {
	my $self = shift;
	return undef if ! $self->{init_status};

	my ($magic, $quote_char) = @_;

	my $in_quotes = 0;
	my $buffer = '';
	my ($line, $sq, $sm);
	my ($posq, $posm) = (-1,-1);

	$line = $self->Read();
	return '' if ! defined $line;
	$buffer .= $line;

	while ( 1 ) {
		$sq = index ($buffer, $quote_char, $posq);
		$sm = index ($buffer, $magic, $posm);

#		print "-> posq=$posq, sq=$sq, posm=$posm, sm=$sm, in_quotes=$in_quotes\n";

		if ( $sm==-1 && $sq==-1 ) {
#			print "-> nix gefunden, weiter lesen\n";
			$line = $self->Read();
			return $buffer if ! defined $line;
			$buffer .= $line;
			next;
		}

		if ( $sq > 0 && substr ($buffer, $sq - 1, 1) eq "\\" ) {
#			print "-> escaped quote gefunden\n";
			$posq = $sq + 1;
			next;
		}

		if ( ($sm!=-1) && ($sm < $sq || $sq==-1) && ! $in_quotes ) {
#			print "-> gueltiges magic gefunden\n";
			$self->Add_To_Buffer
				(substr $buffer, $sm+length($magic));
			return substr $buffer, 0, $sm+length($magic);
		}

		if ( ($sm!=-1) && ($sm < $sq || $sq==-1) && $in_quotes ) {
#			print "-> gequotetes magic gefunden\n";
			$posm = $sm + 1;
			next;
		}

		if ( ($sm!=-1) && ($sq < $sm || $sm==-1) ) {
#			print "-> oeffnendes quote gefunden\n" if !$in_quotes;
#			print "-> schliessendes quote gefunden\n" if $in_quotes;
			$posq = $sq + 1;
			$in_quotes = ($in_quotes ? 0 : 1);
			next;
		}

#		print "-> nix passiert. nochmal lesen\n";
		$line = $self->Read();
		return $buffer if ! defined $line;
		$buffer .= $line;
	}
	return $buffer;		# Achtung, da stand $result! noch nicht gecheckt!
}

sub Set_Comment_Filter {
#
# INPUT:	1. An / Aus
#
# OUTPUT:	-
#
	my $self = shift;
	return undef if ! $self->{init_status};

	my ($comment_filter) = @_;

	$self->{comment_filter} = $comment_filter;
}

sub Get_Line_Number {
#
# INPUT:	-
#
# OUTPUT:	1. Zeilennummer
#
	my $self = shift;
	return undef if ! $self->{init_status};

	return $self->{line};
}

1;
