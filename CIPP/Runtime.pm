#==============================================================================
#
# MODUL
#	CIPP::Runtime.pm
#
# REVISION
#	$Revision: 1.2 $
#
# DESCRIPTION
#	Enthält Funktionen, die zur Laufzeit von CIPP-CGI Programmen
#	benötigt werden
#
# PACKAGE FUNKTIONEN
#	Exception ($die_message)
#		Exception-Handler für fatale Fehler. Die $die_message kann
#		folgende Struktur haben:
#			Message-Typ <TAB> Message
#		Wenn "Message-Typ <TAB>" fehlt, wird als Typ 'general'
#		angenommen.
#		Die Exception wird zusammen mit dem Typ im CIPP Message Log
#		gelogged.
#
#	Log ($type, $message, $filename, $throw)
#		Logged eine $message vom Typ $typ im CIPP Message Log zusammen
#		mit dem aktuellen Timestamp. Wenn $filename ungleich '' ist,
#		wird die Message in die entsprechende Datei geschrieben, sonst
#		in das Standard-CIPP-Message Log.
#		Im Fehlerfalle wird die Exception $throw geworfen.
#
#	$quoted_text = HTML_Quote ($text)
#		Quoted $text so, daß es innerhalb eines <TEXTAREA> verwendet
#		werden kann.
#
#	$quoted_text = Field_Quote ($text)
#		Quoted $text so, daß es innerhalb eines HTML Parameters
#		gefahrlos angewendet werden kann, d.h. es " durch &quot;
#		ersetzt.
#
#	$encoded_text = URL_Encode ($text)
#		URL encoded den übergebenen $text.
#
#	Execute ($name, $query_string, $output)
#		Führt das über den abstrakten Namen $name angegebene CGI
#		Script aus, mit Übergabe von im $query_string definierten 
#		Parametern aus.
#		$output gibt an, was mit der Ausgabe des CGI Scripts geschehen
#		soll.
#		Wird über $output eine Scalarreferenz übergenen, wird die
#		Ausgabe des CGI-Scriptes in dem referenzierten Scalar
#		gespeichert.
#		Ist $output selbst ein Scalar, wird $output als Dateiname
#		interpretiert und die Ausgabe wird in diese Datei geschrieben.
#
#	$url = Get_Object_Url ( $object_name )
#		Gibt die URL des Objektes $object_name zurück
#
#------------------------------------------------------------------------------
# MODIFICATION HISTORY
#	??.??.97 0.1.0.0 joern
#		- Erste Version
#
#	11.03.98 0.1.0.1 joern
#		- Execute: Umstellung auf verzeichnisorientierte Ablage
#		  im prod-Bereich
#		- Execute: Umstellung auf eval statt system Aufruf
#
#	16.03.98 0.1.0.2 joern
#		- Log: zusätzliche Parameter $filename, $throw
#		- Execute: Save-Filehandles auf symb. Referenzen umgestellt,
#		  damit verschachtelte <?EXECUTE> funktionieren
#
#	18.03.98 0.1.0.3 joern
#		- Log: der Name des aktuell ausgeführten CIPP Objekts wird
#		  mit in das Logfile geschrieben
#
#	01.07.98 0.1.0.4 joern
#		- Exception: macht kein die mehr, da es nicht mehr vom
#		  SIG{__DIE__} Handler aus aufgerufen wird, sondern direkt
#		  nach dem eval, welches um den gesamten generierten Code
#		  gefaßt ist. So wird nach außen hin kein Fehlercode gegeben,
#		  so daß der Webserver (bzw. OAS) keinen entsprechenden Fehler
#		  generiert.
#
#	02.07.98 0.1.0.5 joern
#		- Execute: Umbiegen des Error-Handlers ist nun nicht mehr
#		  nötig, da general exceptions mittlerweile über ein globales
#		  eval abgefangen werden
#
#	25.08.98 0.1.0.6 joern
#		- neue Funktion: Get_Object_URL zur dynamischen Auflösung
#		  von Objekt-URL's
#
#	25.10.98 0.1.0.7 joern
#		- Wenn das Script als Apache-Modul ausgeführt wird
#		  ($CIPP_Exec::apache_mod ist gesetzt), dann wird nicht
#		  in das CIPP-Logfile gelogged, sondern direkt in das
#		  Apache-Log
#
#	29.10.98 0.1.0.8 joern
#		- Bugfix: HTML_Quote: < wurde nur einmal übesetzt
#
#	21.11.98 0.1.0.9 joern
#		- Read_Config liest CONFIG's auch dann ein, wenn sich
#		  die Quell-Datei geändert hat (mod_perl)
#
#	04.12.98 0.1.0.10 joern
#		- <?LOG FILE=x> schreibt per Default relativ zu prod/logs
#		- REMOTE_ADDR wird mitgeloggt
#
#	20.12.98 0.2.0.0 joern
#		- <?CONFIG>: prüft, ob Datei vorhanden und wirft Exception,
#		  wenn Datei fehlt.
#
#	16.01.1999 0.3.0.0 joern
#		+ umbenannt von CIPP_Runtime nach CIPP::Runtime
#
#	26.02.1999 0.31 joern
#		+ CIPP Exception Logging starb mit 'die' wenn Logfile
#		  nicht geschrieben werden konnte. Nun gibt es eine
#		  entsprechende Fehlermeldung
#
#==============================================================================

package CIPP::Runtime;

$REVISION = q$Revision: 1.2 $;
$VERSION = "0.31";

use FileHandle;
use Cwd;

sub Read_Config {
	my ($filename, $nocache) = @_;

	die "CONFIG\tDatei '$filename' nicht gefunden" if not -f $filename;
	
	my $file_timestamp = (stat($filename))[9];
	
	if ( $nocache or not defined $CIPP::Runtime::cfg_timestamp{$filename} or
	     $CIPP::Runtime::cfg_timestamp{$filename} < $file_timestamp ) {
		my $fh = new FileHandle;
		open ($fh, $filename);
		eval join ('', <$fh>)."\n1;";
		die "CONFIG\t$@" if $@;
		close $fh;
		$CIPP::Runtime::cfg_timestamp{$filename} = $file_timestamp;
	}
}

sub Exception {
	my ($die_message) = @_;

	my (@type) = split ("\t", $die_message);

	my $message = pop @type;

	if ( (scalar @type) == 0 ) {
		push @type, "general";
	}

	my $type = join ("::", @type);

	my $log_error = Log ("EXC", "TYPE=$type, MESSAGE=$message");
	if ( $log_error ) {
		$message .= "<P><BR><B>Diese Exception konnte nicht im Logfile vermerkt werden!</B><BR>\n";
		$message .= "=> $log_error";
	}
	print "Content-type: text/html\n\n" if ! $CIPP_Exec::cipp_http_header_printed;
	print "<P>$CIPP_Exec::cipp_error_text<P>";

	if ( $CIPP_Exec::cipp_error_show ) {
		$message =~ s/\n/<BR><BR>/;
		$message =~ s/\n/<BR>/g;
		$message =~ s/ at /<P>at /;
	
		print "<P><B>EXCEPTION: </B>$type<BR>\n",
		      "<B>MESSAGE: </B><BR><BLOCKQUOTE><TT>$message</TT></BLOCKQUOTE><P>\n";
		if ( $message =~ /compilation errors/ ) {
			print "<P>Die Compiler-Fehlermeldung finden Sie im Logfile des\n";
			print "Webservers.<P>\n";
		}
	}

#	die "TYPE=$type MESSAGE=$message";
}


sub Log {
	my ($type, $message, $filename, $throw) = @_;
	my $time = scalar (localtime);
	$message =~ s/\s+$//;

	my $program;
	if ( not $CIPP_Exec::apache_mod ) {
		$program = $0;
		$program =~ s!$CIPP_Exec::cipp_cgi_dir/!!;
		$program =~ s!/!.!g;
		$program =~ s!\.cgi$!!;
	} else {
		$program = $CIPP_Exec::apache_program;
	}
	my $msg = "$main::ENV{REMOTE_ADDR}\t$program\t$type\t$message";
	
	my $log_error;
	if ( not $CIPP_Exec::apache_mod ) {
		if ( $filename ne '' ) {
			# wenn relative Pfadangabe, dann relativ zum
			# prod/logs Verzeichnis anlegen
			if ( $filename !~ m!^/! ) {
				my $dir = $CIPP_Exec::cipp_log_file;
				$dir =~ s!/[^/]+$!!;
				$filename = "$dir/$filename";
			}
			
		} else {
			$filename = $CIPP_Exec::cipp_log_file;
		}

		if ( open (cipp_LOG_FILE, ">> $filename") ) {
			if ( ! print cipp_LOG_FILE "$time\t$msg\n" ) {
				$log_error = "Konnte nicht in $filename schreiben";
			}
			close cipp_LOG_FILE;
		} else {
			$log_error = "Konnte $filename nicht zum Schreiben öffnen";
		}
	} else {
		$CIPP_Exec::apache_request->log_error ("Log: $msg");
	}
	
	return $log_error;
}

sub HTML_Quote {
        my ($text) = @_;

        $text =~ s/&/&amp;/g;
        $text =~ s/</&lt;/g;
#       $text =~ s/>/&gt;/g;
        $text =~ s/\"/&quot;/g;

        return $text;
}

sub Field_Quote {
        my ($text) = @_;

	$text =~ s/&/&amp;/g;
        $text =~ s/\"/&quot;/g;

        return $text;
}

sub URL_Encode {
	my ($text) = @_;
	$text =~ s/(\W)/(ord($1)>15)?(sprintf("%%%x",ord($1))):("%0".sprintf("%lx",ord($1)))/eg;

	return $text;
}

sub Execute {
	my ($name, $output, $throw) = @_;

	$throw ||= 'EXECUTE';

	# Dateinamen zum CGI-Objekt-Namen ermitteln

	$name =~ s!\.!/!g;
	my $dir=$name;
	$dir =~ s!/[^/]+$!!;
	$dir = $CIPP_Exec::cipp_cgi_dir."/$dir";
	$script = $CIPP_Exec::cipp_cgi_dir."/$name.cgi";

	# In das CGI Verzeichnis wechseln

	my $cwd_dir = cwd();
	chdir $dir
		or die "$throw\tKonnte nicht nach Verzeichnis $dir wechseln";

	# CGI-Script einlesen

	my $cgi_fh = new FileHandle;
	if ( ! open ($cgi_fh, $script) ) {
		chdir $cwd_dir;
		die "$throw\tKonnte '$script' nicht öffnen";
	}

	my $cgi_script = join ("", <$cgi_fh>);
	close $cgi_fh;

	# STDOUT retten

	my $save_fh = "save".(++$CIPP::Runtime::save_stdout);
	if ( ! open ($save_fh, ">&STDOUT") ) {
		chdir $cwd_dir;
		die "$throw\tKonnte STDOUT nicht duplizieren";
	}

	# Dateinamen für Ausgabe ermitteln:
	#	Wenn Ausgabe in Variable gesetzt werden soll:
	#	-> temp. Dateiname
	#
	#	Wenn Ausgabe in Datei umgelenkt werden soll:
	# 	-> der übergebene Dateiname

	my $catch_file;
	if ( ref ($output) eq 'SCALAR' ) {
		do {
			my $r = int(rand(424242));
			$catch_file = "/tmp/execute".$$.$r;
		} while ( -e $catch_file );
	} else {
		$catch_file = $output;
	}

	# STDOUT auf die Datei umleiten

	close STDOUT;
	if ( ! open (STDOUT, "> $catch_file") ) {
		open (STDOUT, ">&$save_fh")
			or die "$throw\tKonnte STDOUT nicht restaurieren";
		close $save_fh;
		chdir $cwd_dir;
		die "$throw\tKonnte '$catch_file' nicht zum Schreiben öffnen";
	}

	# Löschen des Error-Handlers und Setzen der Variablen
	# $_cipp_no_error_handler. Das verhindert bei dem eval des Scripts das
	# erneute Setzen des Error-Handlers

	$CIPP_Exec::_cipp_in_execute = 1;
	$CIPP_Exec::_cipp_no_http = 1;

	# CGI-Script ausführen, Error-Code merken, Error-Handler zurücksetzen

	eval $cgi_script;
	my $error = $@;

	$CIPP_Exec::_cipp_no_http = undef;
	$CIPP_Exec::_cipp_in_execute = undef;
	
	# wieder ins aktuelle Verzeichnis zurückwechseln

	chdir $cwd_dir;

	# Umleitungsdatei wieder schließen und STDOUT restaurieren

	close STDOUT;
	open (STDOUT, ">&$save_fh")
		or die "$throw\tKonnte STDOUT nicht restaurieren";
	close $save_fh;

	# Wenn Ergebnis in Variable soll, machen wir's doch
	# Vor allem muß das temp. File wieder gelöscht werden

	if ( ref ($output) eq 'SCALAR' ) {
		my $catch_fh = new FileHandle;
		open ($catch_fh, $catch_file)
			or die "$throw\tFehler beim Einlesen der Scriptausgabe";
		$$output = join ("", <$catch_fh>);
		close $catch_fh;
		unlink $catch_file
			or die "$throw\tFehler beim Löschen der Datei '$catch_file'";
	}


#		$main::ENV{REQUEST_METHOD} = $save_request_method;
#		$main::ENV{QUERY_STRING} = $save_query_string;
#		$main::ENV{REQUEST_METHOD} = $save_request_method;
#		$main::ENV{QUERY_STRING} = $save_query_string;



	# Jetzt können wir auch eine Exception werfen, wenn bei der Ausführung
	# des Scripts was schief gelaufen ist (ohne restauriertes STDOUT
	# würde das nicht viel Sinn machen, da dann niemals was beim Benutzer
	# ankommen würde). In diesem Fall wird auch die Ausgabedatei gelöscht.

	if ( $error ne '' ) {
		if ( ref ($output) ne 'SCALAR' ) {
			unlink $catch_file;
		}
		die "$throw\t$error" if $error ne '';
	}

	return 1;
}

sub Get_Object_URL {
#
# INPUT:	1. Objekt
#		2. Exception
#
# OUTPUT:	1. Objekttyp
#
	my ($object, $throw) = @_;
	$throw ||= "geturl";
	
	my $object_name = $object;

	# Prüfen, ob es ein CGI ist

	$object =~ s/\./\//g;	# Punkte durch Slashes ersetzen

	# Projektnamen durch aktuelles Projekt ersetzen
	
	$object =~ s![^\/]*!$CIPP_Exec::cipp_project!;	
	
	# Ist es ein CGI?

	if ( -f "$CIPP_Exec::cipp_cgi_dir/$object.cgi" ) {
		return "$CIPP_Exec::cipp_cgi_url/$object.cgi";
	}
	
	# Dann kann es nur noch ein statisches Dokument sein
	
	my @filenames = <$CIPP_Exec::cipp_doc_dir/$object.*>;
	
	# wenn nicht eindeutig: Fehler!

	if ( scalar @filenames == 0 ) {
		die "$throw\tKonnte Objekt '$object_name' nicht auflösen";
	} elsif ( scalar @filenames > 1 ) {
		die "$throw\tObject-Name '$object_name' ist nicht eindeutig";
	}

	my $file = $filenames[0];
	$file =~ s/^$CIPP_Exec::cipp_doc_dir\///;

	return "$CIPP_Exec::cipp_doc_url/$file";
}



1;
__END__

=head1 NAME

CIPP::Runtime - Runtime library for CIPP generated perl programs

=head1 DESCRIPTION

This module is used by Perl programs which are generated by CIPP.

=head1 AUTHOR

Jörn Reder, joern@dimedis.de

=head1 COPYRIGHT

Copyright 1997-1999 dimedis GmbH, All Rights Reserved

This library is free software; you can redistribute it and/or modify
it under the same terms as Perl itself.

=head1 SEE ALSO

perl(1), CIPP (3pm)
