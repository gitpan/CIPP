package CIPP;

$VERSION = "1.92";
$REVISION = q$Revision: 1.17 $; 

use strict;
use CIPP::InputHandle;
use CIPP::OutputHandle;
use CIPP::DB_DBI;
use CIPP::DB_DBI_old;
use CIPP::DB_Sybase;


# alle Tags, die nicht geschlossen werden
$CIPP::cipp_single_tags =
	"|else|elsif|include|log|throw|autocommit".
	"|execute|dbquote|commit|rollback|my|savefile|config".
	"|htmlquote|urlencode|hiddenfields|img|".
	"|input|geturl|interface|lib|incinterface|getparam|getparamlist".
	"|getdbhandle|autoprint|apredirect|apgetrequest".
# aus Kompatibiltätsgründen
	"|imgurl|cgiurl|docurl|cgiform|";

# alle Tags, die wieder geschlossen werden muessen
$CIPP::cipp_multi_tags  =
	"|if|var|do|while|perl|sql|try|catch|block|foreach|form|a|textarea|sub|";

# Hash-Array fuer alle Tags, als Value wird der Name der behandelnden
# Methode eingetragen
%CIPP::tag_handler = (
		"perl",		"Process_Perl",
		"if", 		"Process_If",
		"while", 	"Process_While",
		"do", 		"Process_Do",
		"var", 		"Process_Var",
		"include", 	"Process_Include",
		"else", 	"Process_Else",
		"elsif", 	"Process_Elsif",
		"execute", 	"Process_Execute",
		"try",		"Process_Try",
		"catch",	"Process_Catch",
		"throw",	"Process_Throw",
		"log",		"Process_Log",
		"block",	"Process_Block",
		"my",		"Process_My",
		"savefile",	"Process_Savefile",
		"sql", 		"Process_Sql",
		"autocommit",	"Process_Autocommit",
		"commit",	"Process_Commit",
		"rollback",	"Process_Rollback",
		"dbquote",	"Process_Dbquote",
		"config",	"Process_Config",
		"htmlquote",	"Process_Htmlquote",
		"urlencode",	"Process_Urlencode",
		"foreach",	"Process_Foreach",
		"geturl",	"Process_Geturl",
		"form",		"Process_Form",
		"img",		"Process_Img",
		"hiddenfields",	"Process_Hiddenfields",
		"input",	"Process_Input",
		"textarea",	"Process_Textarea",
		"a",		"Process_A",
		"interface",	"Process_Interface",
		"lib",		"Process_Lib",
		"incinterface",	"Process_Incinterface",
		"getparam",	"Process_Getparam",
		"getparamlist",	"Process_Getparamlist",
		"getdbhandle",	"Process_Getdbhandle",
		"autoprint",	"Process_Autoprint",
		"apredirect",	"Process_Apredirect",
		"apgetrequest",	"Process_Apgetrequest",
		"sub",		"Process_Sub",
# aus Kompatiblitätsgründen
		"imgurl",	"Process_Imgurl",
		"cgiurl",	"Process_Cgiurl",
		"docurl",	"Process_Docurl",
		"cgiform",	"Process_Cgiform"
);


# requlärer Ausdruck zum URL Codieren
$CIPP::URL_Encode_Expression =
		q{s/(\W)/(ord($1)>15)?}.
                q{(sprintf("%%%x",ord($1))):}.
                q{("%0".sprintf("%lx",ord($1)))/eg};

$CIPP::obj_nr = 0;	# zum Debuggen

sub new {
	my ($type) = shift;
	my ($source, $target, $project_hash, $database_hash, $mime_type,
	    $default_db, $call_path, $skip_header_line, $debugging,
	    $result_type, $use_strict, $persistent, $apache_mod,
	    $project) = @_;

	# Defaults setzen
	$result_type ||= 'cipp';

	my $perl_code = "";
	my $s_handle = new CIPP::InputHandle ($source);
	my $t_handle = new CIPP::OutputHandle ($target);
	my $o_handle = new CIPP::OutputHandle (\$perl_code);

	# back_prod_path ermitteln

	$call_path =~ /^([^:]+)/;
	my $object_name = $1;
	my $back_prod_path = $1;
	$back_prod_path =~ s!\.!/!g;
	$back_prod_path =~ s![^/]+!..!g;

#	print STDERR "back_prod_path = $back_prod_path\n";

	# Objektattribute initialisieren

	my $self = {
			"object_name" => $object_name,
			"obj_nr" => ++$CIPP::obj_nr,
			"version" => $CIPP::VERSION,
			"magic" => "<?",
			"projects" => $project_hash,
			"db_driver" => $database_hash,
			"mime_type" => $mime_type,
			"print_content_type" => 1,
			"write_script_header" => 1,
			"preprocess_status" => 1,
			"call_path" => $call_path,
			"message" => undef,
			"used_macros" => undef,
			"used_databases" => undef,
			"used_images" => undef,
			"perl_code" => \$perl_code,
			"input" => $s_handle,
			"target" => $t_handle,
			"output" => $o_handle,
			"default_db" => $default_db,
			"cipp_db_driver" => undef,
			"skip_header_line" => $skip_header_line,
			"debugging" => $debugging,
			"back_prod_path" => $back_prod_path,
			"result_type" => $result_type,
			"use_strict" => $use_strict,
			"cgi_input" => undef,
			"cgi_optional" => undef,
			"inc_input" => undef,
			"inc_optional" => undef,
			"inc_noinput" => undef,
			"inc_bare" => undef,
			"inc_ouput" => undef,
			"inc_nooutput" => undef,
			"persistent" => $persistent,
			"apache_mod" => $apache_mod,
			"project" => $project
	};

	# Wir gehen mal davon aus, dass alles geklappt hat, pruefen
	# aber nachher zur Sicherheit nochmal nach

	$self->{init_status} = 1;
	$s_handle->Set_Comment_Filter (1);

	# Check auf korrekt initialisierte I/O-Handles und korrektes
	# Projekt-Konfigurationsfile

	if ( ! $s_handle->Get_Init_Status ||
	     ! $t_handle->Get_Init_Status ||
	     ! $o_handle->Get_Init_Status ) {
		$self->{init_status} = 0;
	} elsif ( not $apache_mod ) {
#		my $key;
#		foreach $key (keys %{$project_hash}) {
#			if ( ! -d $$project_hash{$key} ) {
#				$self->{init_status} = 0;
#			}
#		}
	}

	my $blessed = bless $self, $type;

	my $me = $call_path;
	($me) = $me =~ /^([^:\[]+)/;

	$self->{object_url} = $blessed->Get_Object_URL ($me);
#	$self->{init_status} = 0 if ! defined $self->{object_url};

	if ( $self->{init_status} && $skip_header_line ) {
		$blessed->Skip_Header();
	}

#	print STDERR "call_path (", $self->{obj_nr}, "): $call_path\n";

	return $blessed;
}

sub Get_Init_Status {
	my $self = shift;
	return $self->{init_status};
}

sub Skip_Header {
	my $self = shift;
	my $line;
	$self->{input}->Set_Comment_Filter (0);
	while ( $line = $self->{input}->Read() ) {
		last if $line eq $self->{skip_header_line};
	}
	$self->{input}->Set_Comment_Filter (1);
	$self->{input}->{line} = 0;
}

sub Dump {
	my $self = shift;
	return undef if ! $self->{init_status};

	print "input:\t",$self->{input},"\n";
	print "output:\t",$self->{output},"\n";
	print "projects_file:\t",$self->{projects_file},"\n";
	print "mime-type:\t",$self->{mime_type},"\n";
	print "version:\t",$self->{version},"\n";
	print "magic:\t",$self->{magic},"\n";
	print "write_script_header:\t",$self->{write_script_header},"\n";
	print "preprocess_status:\t",$self->{preprocess_status},"\n";
	print "call_path:\t",$self->{call_path},"\n";
	print "default_db:\t",$self->{defualt_db},"\n";
	print "used_macros:\t",$self->{used_macros},"\n";
	print "used_databases:\t",$self->{used_databases},"\n";
	print "message:\t",$self->{message},"\n";
	print "init_status:\t",$self->{init_status},"\n";
	print "debugging:\t",$self->{debugging},"\n";
	print "projects:\n";
	my ($project, $project_root);
	while ( ($project, $project_root) = each %{$self->{projects}} ) {
		print "\t$project:\t$project_root\n";
	}
	print "perl_head:\t$self->perl_head\n";
	print "perl_code:\t${$self->{perl_code}}\n";
}

sub Set_Write_Script_Header {
	my $self = shift;
	return undef if ! $self->{init_status};
	my ($write_script_header) = @_;

	$self->{write_script_header} = $write_script_header;
}

sub Set_Print_Content_Type {
	my $self = shift;
	return undef if ! $self->{init_status};
	my ($print_content_type) = @_;

	$self->{print_content_type} = $print_content_type;
}

sub Get_Preprocess_Status {
	my $self = shift;
	return undef if ! $self->{init_status};

	return $self->{preprocess_status};
}

sub Set_Preprocess_Status {
	my $self = shift;
	return undef if ! $self->{init_status};

	my ($status) = @_;
	$self->{preprocess_status} = $status;
}

sub Get_Messages {
	my $self = shift;
	return undef if ! $self->{init_status};

	return $self->{message};
}

sub Get_Used_Macros {
	my $self = shift;
	return undef if ! $self->{init_status};

	return $self->{used_macros};
}

sub Get_Used_Databases {
	my $self = shift;
	return undef if ! $self->{init_status};

	return $self->{used_databases};
}

sub Get_Used_Configs {
	my $self = shift;
	return undef if ! $self->{init_status};

	return $self->{used_configs};
}

sub Get_Used_Images {
	my $self = shift;
	return undef if ! $self->{init_status};

	return $self->{used_images};
}

sub Get_Include_Inputs {
	my $self = shift;
	return undef if ! $self->{init_status};

	return $self->{inc_input};
}

sub Get_Include_Optionals {
	my $self = shift;
	return undef if ! $self->{init_status};

	return $self->{inc_optional};
}

sub Get_Include_Outputs {
	my $self = shift;
	return undef if ! $self->{init_status};

	return $self->{inc_output};
}

sub Get_Include_Bare {
	my $self = shift;
	return undef if ! $self->{init_status};

	return $self->{inc_bare};
}

sub Add_Message {
	my $self = shift;
	return undef if ! $self->{init_status};

	my ($message, $line) = @_;

	$line ||= $self->{input}->Get_Line_Number();

#	print STDERR "neue Message: (", $self->{obj_nr}, ") ",
#		$self->{call_path}, ": $line - $message\n";

	push @{$self->{message}},
		$self->{call_path}."\t".$line."\t".$message;
}

sub Error {
	my $self = shift;
	return undef if ! $self->{init_status};

	my ($tag, $message, $line) = @_;
	$tag =~ tr/a-z/A-Z/;

	if ( $tag ) {
		$tag = $self->{magic}."$tag>: ";
	}
	
	$self->Add_Message ("$tag$message", $line);
	$self->{preprocess_status} = 0;
}

sub Check_Options {
	my $self = shift;
	return undef if ! $self->{init_status};

	my ($tag, $must_options, $valid_options, $opt) = @_;

	$must_options = ''  if ! defined $must_options;
	$valid_options = '' if ! defined $valid_options;

	if ( $must_options ne '' ) {
		$must_options =~ tr/A-Z/a-z/;
		$must_options =~ s/^\s+//;
		$must_options =~ s/\s+$//;
		$must_options =~ s/\s+/ /g;
		$must_options .= " ";
	}
	if ( $valid_options ne '*' ) {
		$valid_options =~ tr/A-Z/a-z/;
		$valid_options =~ s/^\s+//;
		$valid_options =~ s/\s+$//;
		$valid_options =~ s/\s+/ /g;
		$valid_options .= " ".$must_options;
	}

	my ($option, $foo);
	my $illegal = '';

	# Alle uebergebenenen Optionen durchgehen und aus $must_options
	# rauswerfen ==> wenn $must_options danach nicht leer ist, stehen
	# dort die Optionen drin, die noch fehlen

	while ( ($option, $foo) = each %{$opt} ) {
		$option = quotemeta $option;
		$must_options =~ s/$option\s//;
	}

	# Nun alle uebergebenen Optionen durchgehen und pruefen, ob eine
	# Option uebergeben wurde, die nicht in $valid_options steht. Diese
	# werden dann nach $illegal geschrieben.

	if ( $valid_options ne '' && $valid_options ne '*' ) {
		while ( ($option, $foo) = each %{$opt} ) {
			$option = quotemeta $option;
			if ( $valid_options !~ /$option\s/ ) {
				$illegal .= "$option ";
			}
		}
	}

	# alles OK, wenn $must_options leer und $illegal leer

	return 1 if $must_options eq '' && $illegal eq '';

	if ( $must_options !~ /^\s*$/ ) {
		$must_options =~ s/\s$//;
		$must_options =~ s/\s/,/g;
		$must_options =~ tr/a-z/A-Z/;
		$self->Error ($tag, "fehlende Optionen: $must_options");
	}
	if ( $illegal ne '' ) {
		$valid_options =~ s/\s$//;
		$valid_options =~ s/\s/,/g;
		$illegal =~ tr/a-z/A-Z/;
		$self->Error ($tag, "illegale Optionen: $illegal");
	}

	return 0;
}

sub Check_Nesting {
	my $self = shift;
	return undef if ! $self->{init_status};

	my ($tag, $end_tag) = @_;
	my $nest_index = \$self->{nest_index};
	my $nest_tag = \@{$self->{nest_tag}};
	my $nest_tag_line = \@{$self->{nest_tag_line}};

	if ( ! $end_tag ) {
		# Erst Start-Tags abhandeln

		# Check, ob ELSE an erlaubter Stelle verwendet wird

		if ( $tag eq "else" &&
		     ( ($$nest_index == -1) ||
		       ( ($$nest_tag[$$nest_index] ne "if") &&
		         ($$nest_tag[$$nest_index] ne "elsif")
                       )
                     )
                   ) {
			# wir haben ein ELSE-Tag und haben entweder gar kein
			# Tag vorher (index ist -1), oder haben weder ein IF
			# noch ein ELSIF vorher (ist doch logisch, oder? :)

			$self->Error ("ELSE", "ELSE ohne IF oder ELSIF");
			return 0;
		}

		# Check, ob ELSIF an erlaubter Stelle verwendet wird

		if ( $tag eq "elsif" &&
		     ( ($$nest_index == -1) ||
		       ( ($$nest_tag[$$nest_index] ne "if") &&
		         ($$nest_tag[$$nest_index] ne "elsif")
                       )
                     )
                   ) {
			# wir haben ein ELSIF-Tag und haben entweder gar kein
			# Tag vorher (index ist -1), oder haben weder ein IF
			# noch ein ELSIF vorher (ist doch logisch, oder? :)

			$self->Error ("ELSIF", "ELSIF ohne IF oder ELSIF");
			return 0;
		}
                
		# für alle MULTI-Tags, Schachtelungs-Array setzen

		if ( -1 != index ($CIPP::cipp_multi_tags, "|".$tag."|") ) {
			++$$nest_index;
			$$nest_tag[$$nest_index] = $tag;
			$$nest_tag_line[$$nest_index] =
				$self->{input}->Get_Line_Number();
	        }
	} else {
		# aha, ein Tag wird geschlossen

		# erstmal schauen, ob das ueberhaupt ein Tag ist, was man
		# schliessen kann

		if ( -1 == index ($CIPP::cipp_multi_tags, "|".$tag."|") ) {
			# nee, is verboooten!
			$self->Error ("/$tag", "ist nicht erlaubt");
			return 0;
		}

		# Nun schauen wir mal, ob es dazu denn ueberhaupt ein
		# oeffnendes Tag gibt

		if ( (-1 != $$nest_index) &&
		     ($tag ne $$nest_tag[$$nest_index]) ) {
			# es gab zumindest ein Open-Tag (index != -1), aber
			# das letzte oeffnende Tag passt leider nicht

			my $last_tag = $$nest_tag[$$nest_index];
			$last_tag =~ tr/a-z/A-Z/;
			$tag = "/$tag";
			$tag =~ tr/a-z/A-Z/;
			$self->Error ($tag, "$tag anstelle von /$last_tag");

			return 0;
		}
		if ( -1 == $$nest_index ) {
			# och noe, es gab nicht EIN EINZIGES Open-Tag, das
			# kann doch gar nicht richtig sein!

			$tag = "/$tag";
			$tag =~ tr/a-z/A-Z/;
			$self->Error($tag,
			  "wird geschlossen, ohne dazugehoeriges Start-Tag");

			return 0;
		}

		# Jetzt aber: nun koennen wir den Stack um eins verringern
		--$$nest_index;
	}

	return 1;
}

sub Generate_CGI_Code {
	my $self = shift;
	return if ! $self->{init_status};
	return if ! $self->{write_script_header};

	my $back_prod_path = $self->{back_prod_path};
	my $apache_mod = $self->{apache_mod};
	
	$self->{target}->Write ("#!/usr/local/bin/perl\n") if not $apache_mod;
	$self->{target}->Write ("package CIPP_Exec;\n");
	
	# wenn gefordert, use strict einbauen
	my $use_strict = '';
	if ( $self->{use_strict} ) {
		$use_strict = "use strict;\n";
	}

	my $package_import = '';
	if ( not defined $self->{cgi_input} and not defined $self->{cgi_optional} ) {
		$package_import = q[$cipp_query->import_names('CIPP_Exec');];
	}

	# Headercode generieren
	$self->{target}->Write ($use_strict);
	if ( $apache_mod ) {
		$self->{target}->Write (
			'$CIPP_Exec::apache_mod = 1;'."\n".
			'$CIPP_Exec::apache_program = "'.$self->{call_path}.'";'."\n".
			'$CIPP_Exec::apache_request = $cipp_apache_request;'."\n"
		);
	}
	
	if ( not $apache_mod ) {
		$self->{target}->Write (
q(
local @INC = @INC;
BEGIN {
	require Config;
	if ( $Config::Config{'osname'} =~ /win/i and
	     not defined $CIPP_Exec::_cipp_in_execute ) {
		my $dir = $0;
		$dir =~ s![^/\\\]*$!!;
		chdir $dir;
	}
).qq[
	unshift (\@INC, "$back_prod_path/cgi-bin");
	unshift (\@INC, "$back_prod_path/lib");
}
require '$back_prod_path/config/cipp.conf';
]);
	}
	$self->{target}->Write (
qq[
my \$cipp_query;
if ( ! defined \$CIPP_Exec::_cipp_in_execute ) {
	use CIPP::Runtime;
	use CGI;
	package CIPP_Exec;
	\$cipp_query = new CGI;
	$package_import
}
]);
	if ( not $apache_mod ) {
		$self->{target}->Write (
qq[	
eval { # CIPP-GENERAL-EXCEPTION-EVAL
]);
	}
	$self->{target}->Write (
qq[
package CIPP_Exec;
]);
	if ( $self->{print_content_type} and 
	     $self->{mime_type} ne 'cipp/dynamic' ) {
		$self->{target}->Write (
			"print \"Content-type: ".$self->{mime_type}.
			"\\n\\n\" if not \$CIPP_Exec::_cipp_no_http;\n");

		$self->{target}->Write (
			q{$CIPP_Exec::cipp_http_header_printed = 1;}."\n");
	}
#	print STDERR "mime_type=$self->{mime_type}\n";
	
		if ( $self->{mime_type} eq 'text/html' ) {
			$self->{target}->Write ( 
				"print \"<!-- generated with CIPP ".
				$self->{version}."/$CIPP::REVISION, ".
				"(c) 1997-1999 dimedis GmbH -->\\n\";\n");
		}
#	}
	
	# explizites Importieren von CGI Parameter, wenn $cgi_input
	# angegeben wurde, sonst Importieren in den Namespace über
	# CGI->import_names()

	if ( $self->{cgi_input} ) {
		if ( scalar @{$self->{cgi_input}} ) {
			$self->{target}->Write ("my \@cipp_missing_input;\n");
		}

		my ($var, $var_name);
		foreach $var (@{$self->{cgi_input}}) {
			($var_name = $var) =~ s/[\$\@]//g;
			$self->{target}->Write (
				"my $var = \$cipp_query->param('$var_name');\n".
				"push \@cipp_missing_input, '$var_name' ".
				"if ! defined $var;\n"
			);
		}
		if ( scalar @{$self->{cgi_input}} ) {
			$self->{target}->Write (
				"if ( scalar(\@cipp_missing_input) ) {\n".
				"	die \"CGI_INPUT\tEs fehlen folgende Eingabeparameter:<P>\".\n".
				"	join (', ', \@cipp_missing_input).\"<P>\n\";\n}\n"
			);
		}
		foreach $var (@{$self->{cgi_optional}}) {
			($var_name = $var) =~ s/[\$\@]//g;
			$self->{target}->Write (
				"my $var = \$cipp_query->param('$var_name');\n"
			);
		}
	}
	
	# Footercode generieren
	$self->{output}->Write (
		q[$CIPP_Exec::cipp_http_header_printed = 0;].
		"\n"
	);
	if ( not $apache_mod ) {
		$self->{output}->Write (
			"}; # CIPP-GENERAL-EXCEPTION-EVAL\n".
			"die \$\@ if \$\@ and \$CIPP_Exec::_cipp_in_execute;\n".
			"CIPP::Runtime::Exception(\$\@) if \$\@;\n"
		);
	};
}

sub Generate_Database_Code {
	my $self = shift;
	return if ! $self->{init_status};
	return if ! $self->{write_script_header};
	return if ! defined $self->{used_databases};

	my $apache_mod = $self->{apache_mod};
	
	my $db;

	foreach $db (keys %{$self->{used_databases}}) {
		next if $db eq "$self->{project}.__DEFAULT__";
		
		if ( $apache_mod ) {
			# Parameter aus Apache-Config holen
			$self->{target}->Write (
qq{
\$cipp_db_${db}::data_source = \$cipp_apache_request->dir_config ("db_${db}_data_source");
\$cipp_db_${db}::user = \$cipp_apache_request->dir_config ("db_${db}_user");
\$cipp_db_${db}::password = \$cipp_apache_request->dir_config ("db_${db}_password");
\$cipp_db_${db}::Auto_Commit = \$cipp_apache_request->dir_config ("db_${db}_auto_commit");
}
);
		}
		
#		print STDERR "db=$db\n";
		
		my $driver = $self->{db_driver}{$db};
		$driver =~ s/CIPP_/CIPP::/;
		
		return if not $driver;
		
		my $dbph = $driver->new(
			$db, $self->{back_prod_path}, $self->{persistent}
		);
		$self->{target}->Write ( $dbph->Open ( no_config_require => $apache_mod ));
		$self->{output}->Write ( $dbph->Close );
	}
}

sub Preprocess {
	my $self = shift;
	return undef if ! $self->{init_status};

	# Datenstrukturen zur Verfolgung der Schachtelung von CIPP-Tags

	$self->{nest_tag}[50] = "";	# Stack fuer CIPP-Tags
	$self->{nest_tag_line}[50] = 0;	# In welcher Zeile stand entsprechendes
					# CIPP-Tag
	$self->{nest_index} = -1;	# Aktueller Index in den beiden Arrays

	my $magic = $self->{magic};
	my $magic_reg = quotemeta $self->{magic};

	# Jetzt kann's losgehen, mit dem praeprozessieren (Wort des Jahres :)

	my $chunk = '';
	my $in_print_statement = 1;
	my ($found, $tag, $options, $end_tag, $error, $from_line, $to_line);

	PREPROCESS: while ( 1 ) {

		# wenn als Mime-Type 'cipp/dynamic' angegeben wurde, wird kein HTTP
		# Header generiert und auch keine Print-Befehle. Darum muss sich
		# die Seite nun komplett selber kuemmern. Entsprechend wird das
		# Flag $gen_print gesetzt.
		#
		# Wir machen das für jeden CIPP-Befehl, da sich dieser Zustand
		# während der Übersetzung ändern kann (=> <?AUTOPRINT>)
	
		my $gen_print = $self->{mime_type} eq 'cipp/dynamic' ? 0 : 1;

		$from_line = $self->{input}->Get_Line_Number()+1;
		$chunk = $self->{input}->Read_Cond($magic,1);
		$to_line = $self->{input}->Get_Line_Number();

		$found = ( $chunk =~ /$magic_reg$/ );

#		print STDERR "chunk='$chunk'\n";
#		print STDERR "found=$found\n";

		if ( $found ) {
			# CIPP-Tag gefunden, Bereich davor verarbeiten
			$chunk =~ s/$magic_reg$//;	# Magic entfernen
			$chunk =~ s/\r//g;
#			$chunk =~ s/\n+/\n/g;

			# gelesenen Block ausgeben

			$self->Chunk_Out (\$chunk, $in_print_statement,
					  $gen_print, $from_line);

			# gefundenes CIPP-Tag verarbeiten
			# Ende des Tags suchen

			$chunk = $self->{input}->Read_Cond_Quoted(">",'"');
			my $found_end_of_tag = $chunk =~ s/>\n?$//;

			# Start-Tag herauspopeln

			($tag) = $chunk =~ /^\s*([^\s]+)/;	# Tag holen
			my $orig_tag = $tag;
			$orig_tag =~ s/^\///;
			$tag =~ tr/A-Z/a-z/;			# klein machen

			# Pruefen, ob abschliessendes > ueberhaupt gefunden

			if ( ! $found_end_of_tag ) {
				$self->Error($tag, "> nicht gefunden");
				last;		# dann raus hier, mehr
						# kann nicht getan werden
			}

			# Ok, wir haben ein vollstaendiges Tag gefunden

			$end_tag = ($tag=~s/^\///);	# Ist es ein Ende-Tag?,
							# dann / entfernen und
							# dafuer $end_tag setzen
			
			# Optionen rausholen, d.h. TAG-Bezeichner rausschneiden

			($options = $chunk) =~ s/^\s*[^\s]+\s*//;

#			print "TAG=$tag OPTIONS='$options'\n";
			
			# Ermitteln des Tag-Handlers via definiertem Hash-Array
			my $tag_method = $CIPP::tag_handler{$tag};

			if ( ! defined $tag_method ) {
				# kein interner CIPP Befehl, vielleicht ein Makro
				$options .= " NAME=$orig_tag";
				$tag = "include";
				$tag_method = $CIPP::tag_handler{$tag};
			}

			# mal checken, ob die Schachtelung OK ist
			my $nesting_ok = $self->Check_Nesting ($tag, $end_tag);

			# egal ob Schachtelung OK, wir holen uns auch noch
			# die Optionen, vielleicht gibt's hier ja auch einen
			# Syntaxfehler
			my $opt = Get_Options ($options);

			if ( -1 == $opt ) {
				$tag = "/".$tag if $end_tag;
				$self->Error
				   ($tag, "Syntaxfehler bei den Tag-Parametern");
			} elsif ( -2 == $opt ) {
				$tag = "/".$tag if $end_tag;
				$self->Error ($tag, "Doppelte Tag-Parameter");
			} elsif ( $nesting_ok ) {
				# OK, wir haben keinen Syntaxfehler bei den
				# Optionen und keinen Schachtelungsfehler,
				# dann kann der Tag-Handler aufgerufen werden,
				# nachdem evtl. noch debugging Code erzeugt
				# wurde
				my $big_tag = $tag;
				$big_tag =~ tr/a-z/A-Z/;
				if ( $self->{debugging} && !$end_tag) {
					$self->{output}->Write (
						"# cippline $to_line ".'"'.
						$self->{call_path}.':&lt;?'.
						$big_tag.'>"'."\n" );
				}
				
				# Aufruf der entsprechenden Process_* Methode

				$in_print_statement =
					$self->$tag_method ($opt, $end_tag);
			}
		} else {
			# kein CIPP-Tag im Quelltext gefunden
			$chunk =~ s/\r//g;

			$self->Chunk_Out (\$chunk, $in_print_statement,
					  $gen_print, $from_line);
			last PREPROCESS;
		}
		
#		print STDERR "call_path=$self->{call_path}, ".
#			     "tag=".(($end_tag)?"/":"").
#			     "$tag, nest_index=$self->{nest_index}\n\n";
	}

	# Abschliessend pruefen, ob der Schachtelungsstack aufgeraeumt ist,
	# sprich: gibt es Tags, die nicht geschlossen wurden?

	if ( -1 != $self->{nest_index} ) {
		my $i;
		for ($i = 0; $i <= $self->{nest_index}; ++$i) {
			$self->Error (
				$self->{nest_tag}[$i],
				"wird nicht geschlossen",
				$self->{nest_tag_line}[$i]);
		}
	} else {
		# Code fuer Header generieren

		$self->Generate_CGI_Code();
		$self->Generate_Database_Code ();

		# generierten Perl-Code in die Zieldatei schreiben

		$self->{target}->Write (${$self->{perl_code}});
	}

#	print STDERR "Preprocess (", $self->{obj_nr}, ") END\n";
}


sub Chunk_Out {
#
# INPUT:	1. Referenz auf Chunk
#		2. Befindet Parser sich in einem PRINT Statement
#		3. wie soll der Chunk ausgegeben werden:
#		   1	als print Befehl
#		   0	unverändert
#		   -1	mit Escaping von } Zeichen (für Variablenzuweisung)
#		4. Start-Zeilennummer des Chunks
#		5. Ende-Zeilennummer des Chunks
#
# OUTPUT:	-
#
	my $self = shift;
	my ($chunk_ref, $in_print_statement, $gen_print,
	    $from_line) = @_;
	my $output = $self->{output};

	if ( $$chunk_ref ne '' && $$chunk_ref =~ /[^\r\n\s]/ ) {
		# Chunk ist nicht leer
		if ( 1 == $in_print_statement && $gen_print ) {
			# ggf. Debugging-Code erzeugen
			$output->Write (
				"# cippline $from_line ".'"'.
				 $self->{call_path}.'"'."\n" );

			# Chunk muss via print ausgegeben werden
			$output->Write ("print qq[");
			$$chunk_ref =~ s/\[/\\\[/g;
			$$chunk_ref =~ s/\]/\\\]/g;
			$output->Write ($$chunk_ref);
			$output->Write ("];\n");
		} elsif ( 0 == $in_print_statement ) {
			# Chunk wird unveraendert uebernommen
			$output->Write ($$chunk_ref);
		} elsif ( -1 == $in_print_statement ) {
			# Chunk wird mit escapten } uebernommen
			$$chunk_ref =~ s/\}/\\\}/g;
			$output->Write ($$chunk_ref);
		}
	}
}

sub Format_Debugging_Source {
	my $self = shift;
	
	my $html = "";		# Scalar für den HTML-Code

	my $ar = $self->Get_Messages;
	my $line;

	# Erstmal alle betroffenen Objekte extrahieren und dabei die Fehlermeldungen
	# in ein Hash umschichten
	my %object;
	my %error;
	my @object;
	
	my $i_have_an_error = undef;
	foreach $line (@{$ar}) {
		my ($path, $line, $msg) = split ("\t", $line, 3);
		$path =~ /([^:]+)$/;
		my $name = $1;
		$path =~ s/:$name//;
		if ( not defined $object{$name} ) {
			$object{$name} = $self->Resolve_Object_Source ($name);
			if ( $name ne $self->{object_name} ) {
				push @object, $name;
			} else {
				$i_have_an_error = 1;
			}
		}
		push @{$error{$name}->{$line}}, $msg;
		# Nun noch die Aufrufpfade markieren
		my @path = split (":", $path);
		foreach $name (@path) {
			$name =~ s/\[(\d+)\]//;
			$line = $1;
			push @{$error{$name}->{$line}}, "__INCLUDE_CALL__";
		}
	}

	@object = sort @object;

	unshift @object, $self->{object_name} if $i_have_an_error;
	
	# Alle betroffenen Objekte einlesen
	my %object_source;
	my ($object, $filename);
	while ( ($object, $filename) = each %object ) {
		my $fh = new FileHandle ();
		open ($fh, $filename) or die "can't read $filename";
		local ($_);
		while (<$fh>) {
			s/&/&amp;/g;
			s/</&lt;/g;
			push @{$object_source{$object}}, $_;
		}
		close $fh;
	}
	
	# nun haben wir ein Hash von Listen mit den Quelltextzeilen
	foreach $object (@object) {
		$html .= "<P><HR><H1>$object</H1><P><PRE>\n";
		my ($i, $line);
		$i = 0;
		foreach $line (@{$object_source{$object}}) {
			++$i;
			my $color = "red";
			if ( defined $error{$object}->{$i} ) {
				my $html_msg = "<B><FONT COLOR=blue>";
				my $msg;
				foreach $msg (@{$error{$object}->{$i}}) {
					if ( $msg eq '__INCLUDE_CALL__' ) {
						$color = "green";
						next;
					}
					$html_msg .= "\t$msg\n";
				}
				$html_msg .= "</FONT></B>\n";
				$html .= "\n<B><FONT COLOR=$color>$i\t$line</FONT></B>\n";
				$html .= $html_msg;
			} else {
				$html .= "$i\t$line";
			}
		}
		$html .= "</PRE>\n";
	}
	
	$html .= "<HR>\n";
	
	return \$html;
}


# Unterroutinen für die einzelnen CIPP-Befehle -----------------------------------

sub Process_Perl {
#
# INPUT:	1. Options
#		2. Ende-Tag?
#
# OUTPUT:	1. Danach innerhalb eines PRINT-Statements?
#
	my $self = shift;
	my ($opt, $end_tag) = @_;

	if ( $end_tag ) {
		$self->Check_Options ("/PERL", "", "", $opt) || return 1;
		$self->{output}->Write ("}\n");
		return 1;
	}

	$self->Check_Options ("PERL", "", "COND", $opt) || return 0;

	$self->{output}->Write ("if ($$opt{cond}) ") if defined $$opt{cond};
	$self->{output}->Write ("{;");	# sonst gibt <?PERL><?/PERL> ohne
					# Inhalt einen Syntaxfehler

	return 0;
}

sub Process_If {
#
# INPUT:	1. Options
#		2. Ende-Tag
#
# OUTPUT:	1. Danach innerhalb eines PRINT-Statements?
#
	my $self = shift;
	my ($opt, $end_tag) = @_;

	if ( $end_tag ) {
		$self->Check_Options ("/IF", "", "", $opt) || return 1;
		$self->{output}->Write ("}\n");
		return 1;
	}

	$self->Check_Options ("IF", "COND", "", $opt) || return 1;

	$self->{output}->Write ("if ($$opt{cond}) {\n");

	return 1;
}

sub Process_While {
#
# INPUT:	1. Options
#		2. Ende-Tag?
#
# OUTPUT:	1. Danach innerhalb eines PRINT-Statements?
#
	my $self = shift;
	my ($opt, $end_tag) = @_;

	if ( $end_tag ) {
		$self->Check_Options ("/WHILE", "", "", $opt) || return 1;
		$self->{output}->Write ("}\n");
	} else {
		$self->Check_Options ("WHILE", "COND", "", $opt) || return 1;
		$self->{output}->Write("while ($$opt{cond}) {\n");
	}

	return 1;
}

sub Process_Do {
#
# INPUT:	1. Options
#		2. Ende-Tag?
#
# OUTPUT:	1. Danach innerhalb eines PRINT-Statements?
#
	my $self = shift;
	my ($opt, $end_tag) = @_;

	if ( $end_tag ) {
		$self->Check_Options ("/DO", "COND", "", $opt) || return 1;
		$self->{output}->Write ("} while ($$opt{cond});\n");
	} else {
		$self->Check_Options ("DO", "", "", $opt) || return 1;
		$self->{output}->Write ("do {\n");
	}

	return 1;
}

sub Process_Var {
#
# INPUT:	1. Options
#		2. Ende-Tag?
#
# OUTPUT:	1. -1 als Zeichen, dass keine print generiert werden soll,
#		   die Ausgabe aber mit escapten } erfolgen muss
#
	my $self = shift;
	my ($opt, $end_tag) = @_;

	if ( $end_tag ) {
		$self->Check_Options ("/VAR", "", "", $opt) || return 1;
		my $quote_char = $self->{var_quote} ? '}' : '';
		$self->{output}->Write($quote_char);
		if ( $self->{var_default} ) {
			$self->{output}->Write(
				qq{|| "$self->{var_default}"}
			);
			$self->{var_default} = undef;
		}
		$self->{output}->Write(";\n");
		return 1;
	}

	$self->Check_Options ("VAR", "NAME", "DEFAULT TYPE MY NOQUOTE", $opt)
		|| return 1;

        if ( $$opt{name} !~ /^[\$\@\%]/ ) {
                $$opt{name} = "\$".$$opt{name};
        }

	if ( $$opt{name} =~ /^[\@\%]/ ) {
		if ( defined $$opt{default} ) {
			$self->Error ("VAR", "DEFAULT kann nur bei skalaren ".
			"Variablen verwendet werden");
			return 0;
		}
		$self->{var_quote} = 0;
	} else {
        	$self->{var_quote} = 1;
	}

        if ( defined ($$opt{type}) ) {
		$$opt{type} =~ tr/A-Z/a-z/;
		if ( $$opt{type} eq "num" ) {
			$self->{var_quote} = 0;
		} else {
			$self->Error ("VAR", "Ungültiger TYPE");
			return 0;
		}
	}

	if ( defined $$opt{noquote} ) {
		$self->{var_quote} = 0;
	}

	my $quote_char = $self->{var_quote} ? 'qq{' : '';
	my $quote_end_char = $self->{var_quote} ? '}' : '';

	$self->{output}->Write("my ") if defined $$opt{'my'};

        if ( defined ($$opt{default}) ) {
		$self->{var_default} = $$opt{default};
	}
#		$self->{output}->Write("$$opt{name}=");
#		$self->{output}->Write(
#			"$$opt{name} eq '' ?".
#			$quote_char."$$opt{default}".
#			$quote_end_char.":".$quote_char);
#        } else {
		$self->{output}->Write("$$opt{name}=".$quote_char);
#        }

	return $self->{var_quote} ? -1 : 0;
}

sub Process_Include {
#
# INPUT:	1. Options
#		2. Ende-Tag?
#
# OUTPUT:	1. Danach innerhalb eines PRINT-Statements?
#
	my $self = shift;
	my ($opt, $end_tag) = @_;

	$self->Check_Options ("INCLUDE", "NAME", "*", $opt) || return 1;

	# Pruefen, ob rekursiver Aufruf vorliegt

	if ( $self->{call_path} =~ /:$$opt{name}\[/ ) {
		$self->Error (
			"INCLUDE",
			$$opt{name}." wird rekursiv angewendet. ".
			"Aufrufpfad: ".$self->{call_path}
		);
		return 1;
	}

	my $name = $$opt{name};
	delete $$opt{name};
	my $my = $$opt{my};
	delete $$opt{my};

	# Ausgabeparameter aus $opt aussortieren
	
	my ($var_output, $var);

	foreach $var ( keys %{$opt} ) {
		if ( $var =~ /^[\$\@\%]/ ) {
			# Ausgabeparameter fangen mit $, @, % an
			my $var_name = $opt->{$var};
			$var_name =~ tr/A-Z/a-z/;
			$var_output->{$var_name} = $var;
			delete $opt->{$var};
		}
	}


	# Macro-Abhaengigkeitsliste aktualisieren
	$self->{used_macros}->{$name} = 1;

	# Dateinamen des Macros bestimmen
	my $macro_file = $self->Resolve_Object_Source ($name, 'cipp-inc');

	if ( ! defined $macro_file  ) {
		$self->Error ("INCLUDE", "Konnte Objekt '$name' nicht auflösen.");
		return 1;
	}

	if ( ! -r $macro_file ) {
		$self->Error ("INCLUDE", "Kann '$name' nicht finden. Datei: $macro_file, $macro_file");
		return 1;
	}


	# Präprozessor initialisieren

	my $code;
	my $MACRO = new CIPP
		($macro_file, \$code, $self->{projects},
		 $self->{db_driver}, $self->{mime_type},
		 $self->{default_db}, $self->{call_path}.
		 "[".$self->{input}->Get_Line_Number."]:".$name,
		 $self->{skip_header_line}, $self->{debugging},
		 $self->{result_type}, $self->{use_strict},
		 $self->{persistent}, $self->{apache_mod},
		 $self->{project});

	if ( ! $MACRO->Get_Init_Status ) {
		$self->Error ("INCLUDE", "Interner Fehler bei CIPP Init");
		return 1;
	}

	# Übersetzen des Macros

	$MACRO->Set_Write_Script_Header (0);
	$MACRO->Preprocess ();

	# Ist die Übergabe von Parametern verboten, es wurden aber
	# doch welche angegeben?
	
	if ( $MACRO->{inc_noinput} and scalar(keys %{$opt}) ) {
		$self->Error ("INCLUDE", "Es dürfen keine Parameter an $name übergeben werden");
		return 1;
	}
	if ( $MACRO->{inc_nooutput} and scalar(keys %{$var_output}) ) {
		$self->Error ("INCLUDE", "$name hat keine Ausgabeparameter");
		return 1;
	}
	

	# wenn eine Schnittstelle spezifiziert wurde,
	# ist sie auch eingehalten?

	my $param_must    = $MACRO->Get_Include_Inputs();
	my $param_opt     = $MACRO->Get_Include_Optionals();
	my $param_bare    = $MACRO->Get_Include_Bare();
	my $param_output  = $MACRO->Get_Include_Outputs();
	
	# Array für fehlerhafte Parameter
	
	my (@missing_params, @unknown_params, @unknown_output);


	# Eingabeparameter checken

	# Wurden alle MUSS-Parameter angegeben?

	if ( defined $param_must ) {
		my $i;
		foreach $i (keys %{$param_must}) {
			if ( not defined $$opt{$i} ) {
				push @missing_params, $i;
			}
		}
	}
	
	# Wurden unbekannte Eingabeparameter übergeben?

	foreach my $i ( keys %{$opt} ) {
		next if defined $param_opt->{$i};
		next if defined $param_must->{$i};
		push @unknown_params, $i;
	}

#	if ( defined $param_opt or defined $param_must ) {
#		my $i;
#		foreach $i ( keys %{$opt} ) {
#			next if defined $param_opt->{$i};
#			next if defined $param_must->{$i};
#			push @unknown_params, $i;
#		}
#	}
	
	# Wurden unbekannte Ausgabeparameter angegeben
	
	if ( defined $param_output ) {
		my $i;
		foreach $i (keys %{$var_output}) {
			if ( not defined $param_output->{$i} ) {
				push @unknown_output, $i;
			}
		}
	}


	# Code für die übergebenen Parameter generieren

	my $code_if;

	my ($par, $val);
	while ( ($par, $val) = each %{$opt} ) {
		my $q_open = "qq{";
		my $q_close = "}";
		my $var_name;
		
		$var_name = $param_must->{$par} if defined $param_must->{$par};
		$var_name = $param_opt->{$par}  if defined $param_opt->{$par};
		
		# wenn keine Schnittstelle spezifiert wurde, dann wird der
		# Parameter als Skalar interpretiert
		
		$var_name = "\$$par" if ! defined $var_name;
		
		if ( defined $param_bare->{$par} ) {
			$q_open = '';
			$q_close = '';
		}

		$code_if .= "my $var_name = ${q_open}${val}${q_close};\n";
	}

	# Wenn wir 'use strict' Code generieren sollen, müssen nun noch
	# alle optionalen und Ausgabe-Parameter, die nicht übergeben wurden,
	# mit my deklariert werden
	
	if ( $self->{use_strict} ) {
		my ($name, $var);
		while ( ($name, $var) = each %{$param_opt}) {
			if ( not defined $$opt{$name} ) {
				$code_if .= "my $var;\n";
			}
		}
		
		while ( ($name, $var) = each %{$param_output}) {
			if ( not defined $var_output->{$name} ) {
				$code_if .= "my $var;\n";
			}
		}
	}

	# Nun Code für eventuelle Ausgabeparameter generieren
	
	my ($code_out_before, $code_out_after) = ('', '');
	
#	print STDERR "name=$name, param_output=$param_output\n";

	my (@wrong_types, @equal_names);
		
	if ( defined $param_output ) {
		my ($name, $var);
		my @declare;
		while ( ($name, $var) = each %{$var_output} ) {
#			print STDERR "var=$var, name=$name\n";
			if ( defined $param_output->{$name} ) {
				push @declare, $var;
				$code_if .= "my ".$param_output->{$name}.";\n";
#				print STDERR "name=$name\n";
				if ( $var eq $param_output->{$name} ) {
					push @equal_names, $var;
				}
				$code_out_after .= $var."=".$param_output->{$name}.";\n";
				if ( substr($var,0,1) ne substr($param_output->{$name},0,1) ) {
					my $type = substr($param_output->{$name},0,1);
					my $correct = $var;
					$correct =~ s/^./$type/;
					push @wrong_types, "$var. Richtig wäre: $correct";
				}
			}
		}
		if ( scalar(@declare) and $my ) {
			$code_out_before = 'my ('.(join(",",@declare)).");\n";
		}
	}

	# Hash der benutzten Macros aus der Liste des Macros aktualisieren
	my ($macro, $foo);
	if ( defined $MACRO->Get_Used_Macros() ) {
		while ( ($macro, $foo) = each %{$MACRO->Get_Used_Macros()} ) {
			$self->{used_macros}{$macro} = 1;
		} 
	}

	# Hash der benutzten Datenbanken aus der Liste des Macros aktualisieren
	my $db;
	if ( defined $MACRO->Get_Used_Databases() ) {
		while ( ($db, $foo) = each %{$MACRO->Get_Used_Databases()} ) {
			$self->{used_databases}{$db} = 1;
		} 
	}

	# Hash der benutzten Bilder aus der Liste des Macros aktualisieren
	my $image;
	if ( defined $MACRO->Get_Used_Images() ) {
		while ( ($image, $foo) = each %{$MACRO->Get_Used_Images()} ) {
			$self->{used_images}{$image} = 1;
		} 
	}

	# Hash der benutzten Configs aus der Liste des Macros aktualisieren
	my $image;
	if ( defined $MACRO->Get_Used_Configs() ) {
		while ( ($image, $foo) = each %{$MACRO->Get_Used_Configs()} ) {
			$self->{used_configs}{$image} = 1;
		} 
	}

	# Meldungsliste updaten
	# Zunächst Fehler bezüglich der Schnittstelle
	
	if ( scalar(@missing_params) ) {
		my $i;
		foreach $i (@missing_params) {
			$self->Error ("INCLUDE", "Fehlender Eingabeparameter: $i");
		}
	}

	if ( scalar(@unknown_params) ) {
		my $i;
		foreach $i (@unknown_params) {
			$self->Error ("INCLUDE", "Unbekannter Eingabeparameter: $i");
		}
	}

	if ( scalar(@unknown_output) ) {
		my $i;
		foreach $i (@unknown_output) {
			$self->Error ("INCLUDE", "Unbekannter Ausgabeparameter: $i");
		}
	}

	if ( scalar(@wrong_types) ) {
		my $i;
		foreach $i (@wrong_types) {
			$self->Error ("INCLUDE", "Falscher Ausgabeparametertyp: $i");
		}
	}

	if ( scalar(@equal_names) ) {
		my $i;
		foreach $i (@equal_names) {
			$self->Error ("INCLUDE", "Ausgabevariable heißt wie Ausgabeparameter: $i");
		}
	}

	# Dann Fehler merken, die im Macro selber liegen

	if ( defined $MACRO->Get_Messages() ) {
		push @{$self->{message}}, @{$MACRO->Get_Messages()};
	}

	if ( ! $MACRO->Get_Preprocess_Status() ) {
		$self->Set_Preprocess_Status(0);
		return 1;
	}

	
	# Code ausgeben
	$self->{output}->Write (
		$code_out_before.
		"{\n".$code_if."{\n".$code.
		"}\n".
		$code_out_after.
		"}\n"
	);

	return 1;
}

sub Process_Else {
#
# INPUT:	1. Options
#		2. Ende-Tag?
#
# OUTPUT:	1. Danach innerhalb eines PRINT-Statements?
#
	my $self = shift;
	my ($opt, $end_tag) = @_;

	$self->Check_Options ("ELSE", "", "", $opt) || return 1;

	$self->{output}->Write ("} else {\n");

	return 1;
}

sub Process_Elsif {
#
# INPUT:	1. Options
#		2. Ende-Tag?
#
# OUTPUT:	1. Danach innerhalb eines PRINT-Statements?
#
	my $self = shift;
	my ($opt, $end_tag) = @_;

	$self->Check_Options ("ELSIF", "COND", "", $opt) || return 1;

	$self->{output}->Write ("} elsif ($$opt{cond}) {\n");

	return 1;
}


sub Process_Sql {
#
# INPUT:	1. Options
#		2. Ende-Tag?
#
# OUTPUT:	1. Danach innerhalb eines PRINT-Statements?
#
	my $self = shift;
	my ($opt, $end_tag) = @_;

	if ( $end_tag ) {
		# wenn {driver_used} nicht existiert, war vorher ein Syntax-
		# fehler aufgetreten, dann braucht auch kein Ende-Code erzeugt
		# zu werden
		if ( defined $self->{driver_used} ) {
			$self->{output}->Write ($self->{driver_used}->End_SQL());
		}
		$self->{driver_used} = undef;
		return 1;
	}

	if ( defined $self->{driver_used} ) {
		$self->Error ("SQL", "Verschachtelung von SQL nicht erlaubt");
		return 1;
	}

	$self->Check_Options (
		"SQL", "", 
		"SQL DB VAR PARAMS RESULT THROW MAXROWS WINSTART WINSIZE MY",
		$opt) || return 1;

	if ( defined $$opt{winstart} ^ defined $$opt{winsize} ) {
		$self->Error ("SQL", "WINSTART und WINSIZE müssen immer ".
			      "gemeinsam angegeben werden");
		return 1;
	}

	if ( defined $$opt{winstart} && defined $$opt{maxrows} ) {
		$self->Error ("SQL", "MAXROWS kann nicht in Kombination mit ".
			      "WINSTART und WINSIZE verwendet werden");
		return 1;
	}

	my $db = $$opt{db} || $self->{default_db};
	$self->{used_databases}{$db} = 1 if defined $db;
	$self->{used_databases}{$self->{project}.".__DEFAULT__"} = 1 if ! defined $$opt{db};

	if ( ! defined $db ) {
		$self->Error ("SQL", "es ist keine Default DB definiert");
		return 1;
	}

	my $driver = $self->{db_driver}{$db};
	$driver =~ s/CIPP_/CIPP::/;

	if ( ! defined $driver ) {
		$self->Error ("SQL", "Datenbank '$db' unbekannt");
		return 1;
	}

	my @var;
	if ( defined $$opt{var} ) {
		@var = split (/\s*,\s*/, $$opt{var});
		my $v;
		foreach $v (@var) {
			$v =~ s/^\$//;
		}
	}
	
	my @input;
	if ( defined $$opt{params} ) {
		@input = split (/\s*,\s*/, $$opt{params});
#		my $v;
#		foreach $v (@input) {
#			$v = "\$$v" if $v !~ /^[\$\@]/;
#		}
	}
	
	$$opt{throw} ||= "sql";

	$self->{driver_used} = $driver->new($db, $self->{back_prod_path});

	$self->{output}->Write (
		$self->{driver_used}->Begin_SQL
			($$opt{sql}, $$opt{result}, $$opt{throw},
			 $$opt{maxrows}, $$opt{winstart}, $$opt{winsize},
			 $$opt{my}, \@input, @var)
	);

	return 1;
}

sub Process_Commit {
	my $self = shift;
	my ($opt, $end_tag) = @_;

	$self->Check_Options ("COMMIT", "", "DB THROW", $opt) || return 1;

	my $db = $$opt{db} || $self->{default_db};
	$self->{used_databases}{$db} = 1 if defined $db;
	$self->{used_databases}{$self->{project}.".__DEFAULT__"} = 1 if ! defined $$opt{db};

	if ( ! defined $db ) {
		$self->Error ("COMMIT", "es ist keine Default DB definiert");
		return 1;
	}

	my $driver = $self->{db_driver}{$db};
	$driver =~ s/CIPP_/CIPP::/;
	
	if ( ! defined $driver ) {
		$self->Error ("COMMIT", "Datenbank '$db' unbekannt");
		return 1;
	}

	my $dr = $driver->new($db, $self->{back_prod_path});

	$$opt{throw} ||= "commit";

	$self->{output}->Write ($dr->Commit($$opt{throw}));

	return 1;
}

sub Process_Rollback {
	my $self = shift;
	my ($opt, $end_tag) = @_;

	$self->Check_Options ("ROLLBACK", "", "DB THROW", $opt) || return 1;

	my $db = $$opt{db} || $self->{default_db};
	$self->{used_databases}{$db} = 1 if defined $db;
	$self->{used_databases}{$self->{project}.".__DEFAULT__"} = 1 if ! defined $$opt{db};

	if ( ! defined $db ) {
		$self->Error ("ROLLBACK", "es ist keine Default DB definiert");
		return 1;
	}

	my $driver = $self->{db_driver}{$db};
	$driver =~ s/CIPP_/CIPP::/;

	if ( ! defined $driver ) {
		$self->Error ("ROLLBACK", "Datenbank '$db' unbekannt");
		return 1;
	}

	my $dr = $driver->new($db, $self->{back_prod_path});

	$$opt{throw} ||= "rollback";

	$self->{output}->Write ($dr->Rollback($$opt{throw}));

	return 1;
}

sub Process_Autocommit {
	my $self = shift;
	my ($opt, $end_tag) = @_;

	$self->Check_Options ("AUTOCOMMIT", "", "ON OFF DB THROW", $opt)
		 || return 1;

	my $db = $$opt{db} || $self->{default_db};
	$self->{used_databases}{$db} = 1 if defined $db;
	$self->{used_databases}{$self->{project}.".__DEFAULT__"} = 1 if ! defined $$opt{db};

	if ( ! defined $db ) {
		$self->Error ("AUTOCOMMIT", "es ist keine Default DB definiert");
		return 1;
	}

	my $driver = $self->{db_driver}{$db};
	$driver =~ s/CIPP_/CIPP::/;

	if ( ! defined $driver ) {
		$self->Error ("AUTOCOMMIT", "Datenbank '$db' unbekannt");
		return 1;
	}

	if ( !defined $$opt{on} && !defined $$opt{off} ) {
		$self->Error ("AUTOCOMMIT", "weder ON noch OFF angegeben");
		return 1;
	}

	my $status = 1;
	$status = 0 if defined $$opt{off};

	my $dr = $driver->new($db, $self->{back_prod_path});

	$$opt{throw} ||= "autocommit";

	$self->{output}->Write ($dr->Autocommit($status, $$opt{throw}));

	return 1;
}

sub Process_Getdbhandle {
	my $self = shift;
	my ($opt, $end_tag) = @_;

	$self->Check_Options ("GETDBHANDLE", "VAR", "MY", $opt)
		 || return 1;

	my $db = $$opt{db} || $self->{default_db};
	$self->{used_databases}{$db} = 1 if defined $db;
	$self->{used_databases}{$self->{project}.".__DEFAULT__"} = 1 if ! defined $$opt{db};

	if ( ! defined $db ) {
		$self->Error ("GETDBHANDLE", "es ist keine Default DB definiert");
		return 1;
	}

	my $driver = $self->{db_driver}{$db};
	$driver =~ s/CIPP_/CIPP::/;

	if ( ! defined $driver ) {
		$self->Error ("GETDBHANDLE", "Datenbank '$db' unbekannt");
		return 1;
	}

	$$opt{var} = '$'.$$opt{var} if $$opt{var} !~ /^\$/;

	my $dr = $driver->new($db, $self->{back_prod_path});

	$self->{output}->Write ($dr->Get_DB_Handle($$opt{var}, $$opt{my}));

	return 1;
}



sub Process_Execute {
#
# INPUT:	1. Options
#		2. Ende-Tag?
#
# OUTPUT:	1. Danach innerhalb eines PRINT-Statements?
#
	my $self = shift;
	my ($opt, $end_tag) = @_;

	if ( $self->{apache_mod} ) {
		$self->Error ("EXECUTE", "Der EXECUTE Befehl wird z.Zt. im Apache-Modus nicht unterstützt");
		return 1;
	}

	$self->Check_Options ("EXECUTE", "NAME", "*", $opt);

	my $name = $$opt{name};
	delete $$opt{name};

	if ( (!defined $$opt{var}) && (!defined $$opt{filename}) ) {
		$self->Error ("EXECUTE", "VAR oder FILENAME muss angegeben werden");
		return 1;
	}
	if ( defined $$opt{var} && defined $$opt{filename} ) {
		$self->Error ("EXECUTE", "VAR und FILENAME dürfen nicht zusammen".
			      " angegeben werden");
		return 1;
	}

	my $throw = $$opt{throw} || 'EXECUTE';

	# Parameter übergeben

#	my $code = "{\n";
	my $code = '';
	
	my ($par, $val);
	while ( ($par, $val) = each %{$opt} ) {
		next if $par eq 'var' or $par eq 'filename' or
			$par eq 'throw' or $par eq 'my';
		$val =~ s/\]/\\\]/g;
		$code .= qq{\$CIPP_Exec::$par=qq[$val];\n};
	}

	# CIPP::Runtime::Execute() aufrufen

	if ( defined $$opt{var} ) {
		$$opt{var} = '$'.$$opt{var} if $$opt{var} !~ /^\$/;
		$code .= qq{my $$opt{var};\n} if $$opt{my};
		$code .= qq{CIPP::Runtime::Execute}.
			 qq{("$name",}.
			 qq{\\$$opt{var},"$throw");\n};
	} else {
		$code .= qq{CIPP::Runtime::Execute}.
			 qq{("$name",}.
			 qq{"$$opt{filename}","$throw");\n};
	}
#	$code .= "}\n";

	$self->{output}->Write ($code);

	return 1;
}


sub Process_Dbquote {
#
# INPUT:	1. Options
#		2. Ende-Tag?
#
# OUTPUT:	1. Danach innerhalb eines PRINT-Statements?
#
	my $self = shift;
	my ($opt, $end_tag) = @_;

	$self->Check_Options ("DBQUOTE", "VAR", "DBVAR DB MY", $opt) || return 1;

        if ( $$opt{var} !~ /^\$/ ) {
                $$opt{var} = "\$".$$opt{var};
        }
        if ( defined $$opt{dbvar} ) {
            if ( $$opt{dbvar} !~ /^\$/ ) {
                $$opt{dbvar} = "\$".$$opt{dbvar};
            }
        } else {
                ( $$opt{dbvar} = $$opt{var} ) =~ s/^\$(.*)$/\$db_$1/;
        }

	my $db = $$opt{db} || $self->{default_db};
	$self->{used_databases}{$db} = 1 if defined $db;
	$self->{used_databases}{$self->{project}.".__DEFAULT__"} = 1 if ! defined $$opt{db};

	if ( ! defined $db ) {
		$self->Error ("AUTOCOMMIT", "es ist keine Default DB definiert");
		return 1;
	}

	my $driver = $self->{db_driver}{$db};
	$driver =~ s/CIPP_/CIPP::/;

	my $dh = $driver->new ($db, $self->{back_prod_path});

	$self->{output}->Write (
		$dh->Quote_Var ($$opt{var}, $$opt{dbvar}, $$opt{my})
	);

	return 1;
}


sub Process_Try {
#
# INPUT:	1. Options
#		2. Ende-Tag?
#
# OUTPUT:	1. Danach innerhalb eines PRINT-Statements?
#
	my $self = shift;
	my ($opt, $end_tag) = @_;

	$self->Check_Options ("TRY", "", "", $opt) || return 1;

	if ( $end_tag ) {
		$self->{output}->Write (
			"};\n".
			"(\$cipp_exception, \$cipp_exception_msg)=".
			"split(\"\\t\",\$\@,2);\n".
			'$cipp_exception_msg=$cipp_exception '.
			'if $@ && $cipp_exception_msg eq "";'."\n"
		);
		return 1;
	}

	$self->{output}->Write (
		"my (\$cipp_exception,\$cipp_exception_msg)=(undef,undef);\n".
		"eval {\n"
	);

	return 1;
}

sub Process_Catch {
#
# INPUT:	1. Options
#		2. Ende-Tag?
#
# OUTPUT:	1. Danach innerhalb eines PRINT-Statements?
#
	my $self = shift;
	my ($opt, $end_tag) = @_;

	$self->Check_Options ("CATCH", "", "THROW MY EXCVAR MSGVAR", $opt)
		or return 1;

	if ( $end_tag ) {
		$self->{output}->Write ("}\n");
		return 1;
	}
	my $my = '';
	$my = 'my ' if defined $$opt{my};
	
	if ( defined $$opt{excvar} ) {
                $$opt{excvar} = "\$".$$opt{excvar} if $$opt{excvar} !~ /^\$/;
		$self->{output}->Write ("${my}$$opt{excvar} = \$cipp_exception;\n");
	}

	if ( defined $$opt{msgvar} ) {
                $$opt{msgvar} = "\$".$$opt{msgvar} if $$opt{msgvar} !~ /^\$/;
		$self->{output}->Write ("${my}$$opt{msgvar} = \$cipp_exception_msg;\n");
	}

	if ( defined $$opt{throw} ) {
		$self->{output}->Write (
			'if ( $cipp_exception eq "'.$$opt{throw}.'" ) {'."\n"
		);
	} else {
		$self->{output}->Write (
			"if ( defined \$cipp_exception ) {\n"
		);
	}

	return 1;
}

sub Process_Log {
#
# INPUT:	1. Options
#		2. Ende-Tag?
#
# OUTPUT:	1. Danach innerhalb eines PRINT-Statements?
#
	my $self = shift;
	my ($opt, $end_tag) = @_;

	$self->Check_Options ("LOG", "MSG", "TYPE FILENAME THROW", $opt)
		|| return 1;

	$$opt{type} = "APP" if ! defined $$opt{type};
	$$opt{filename} = "" if ! defined $$opt{filename};
	$$opt{throw} = "LOG" if ! defined $$opt{throw};

	$self->{output}->Write (
		qq{CIPP::Runtime::Log ("$$opt{type}", "$$opt{msg}", }.
		qq{"$$opt{filename}", "$$opt{throw}");\n}
	);

	return 1;
}

sub Process_Throw {
#
# INPUT:	1. Options
#		2. Ende-Tag?
#
# OUTPUT:	1. Danach innerhalb eines PRINT-Statements?
#
	my $self = shift;
	my ($opt, $end_tag) = @_;

	$self->Check_Options ("THROW", "THROW", "MSG", $opt) || return 1;

	if ( defined $$opt{msg} ) {
		$self->{output}->Write (
			qq{die "$$opt{throw}\t$$opt{msg}";\n}
		);
	} else {
		$self->{output}->Write (
			qq{die "$$opt{throw}\t";\n}
		);
	}

	return 1;
}

sub Process_Block {
#
# INPUT:	1. Options
#		2. Ende-Tag?
#
# OUTPUT:	1. Danach innerhalb eines PRINT-Statements?
#
	my $self = shift;
	my ($opt, $end_tag) = @_;

	$self->Check_Options ("BLOCK", "", "", $opt) || return 1;

	if ( $end_tag ) {
		$self->{output}->Write ("}\n");
		return 1;
	}

	$self->{output}->Write ("{\n");

	return 1;
}

sub Process_My {
#
# INPUT:	1. Options
#		2. Ende-Tag?
#
# OUTPUT:	1. Danach innerhalb eines PRINT-Statements?
#
	my $self = shift;
	my ($opt, $end_tag) = @_;

	if ( ! defined $opt ) {
		$self->Error ("MY", "keine Parameter angegeben");
		return 1;
	}

	if ( defined $$opt{var} ) {
		my $v;
		foreach $v ( split (/\s*,\s*/, $$opt{var}) ) {
			$$opt{$v} = 1;
		}
		delete $$opt{var};
	}

	my $var;
	my $error = 0;
	foreach $var (keys %{$opt}) {
		if ( $var !~ /^[\$\%\@\*]/ ) {
			$self->Error ("MY", "$var ist ein Bareword");
			$error = 1;
		}
	}
	return 1 if $error;

	my $varlist = join (",", keys %{$opt});

	$self->{output}->Write ("my ($varlist);\n");

	return 1;
}

sub Process_Savefile {
#
# INPUT:	1. Options
#		2. Ende-Tag?
#
# OUTPUT:	1. Danach innerhalb eines PRINT-Statements?
#
	my $self = shift;
	my ($opt, $end_tag) = @_;

	$self->Check_Options ("SAVE_FILE", "VAR FILENAME",
			      "THROW SYMBOLIC", $opt)
		|| return 1;

	$$opt{var} =~ s/^\$//;

	$$opt{throw} ||= "savefile";

	my $formvar;
	if ( ! defined $$opt{symbolic} ) {
		$formvar = "'$$opt{var}'";
	} else {
		$formvar = "\$$$opt{var}";
	}

	my $code = "{\nno strict;\n";
	$code .= "open (cipp_SAVE_FILE, \"> $$opt{filename}\")\n";
	$code .= "or die \"$$opt{throw}\tDatei '$$opt{filename}' ".
		 "kann nicht zum Schreiben geoffnet werden\";\n";
	$code .= "my \$cipp_filehandle = \$cipp_query->param($formvar);\n";
	$code .= "binmode cipp_SAVE_FILE;\n";
	$code .= "binmode \$cipp_filehandle;\n";
	$code .= "my (\$cipp_filebuf, \$cipp_read_result);\n";
	$code .= "while (\$cipp_read_result = read \$cipp_filehandle, ".
		 "\$cipp_filebuf, 1024) {\n";
	$code .= "print cipp_SAVE_FILE \$cipp_filebuf ";
	$code .= "or die \"$$opt{throw}\tFehler beim Schreiben der Upload-Datei\";\n";
	$code .= "}\n";
	$code .= "close cipp_SAVE_FILE;\n";
	$code .= "(!defined \$cipp_read_result) and \n";
	$code .= "die \"$$opt{throw}\tFehler beim Lesen der Upload-Datei. Wurde ENCTYPE=multipart/form-data beim Upload-Formular angegeben?\";\n";
	$code .= "close \$cipp_filehandle;\n";
	$code .= "}\n";
	
	$self->{output}->Write ($code);

	return 1;
}


sub Process_Config {
#
# INPUT:	1. Options
#		2. Ende-Tag?
#
# OUTPUT:	1. Danach innerhalb eines PRINT-Statements?
#
	my $self = shift;
	my ($opt, $end_tag) = @_;

	$self->Check_Options ("CONFIG", "NAME", "NOCACHE RUNTIME THROW", $opt) || return 1;
	my $back_prod_path = $self->{back_prod_path};

	my $name = $$opt{name};
	my $apache_mod = $self->{apache_mod};
	
	if ( not $$opt{runtime} and not $apache_mod ) {
		$name =~ s/^[^\.]+//;
		$name = $self->{project}.$name;
		if ( ! defined $self->Object_Exists($name) ) {
			$self->Error("CONFIG", "Objekt '$name' existiert nicht");
			return 1;
		}
		if ( $self->Get_Object_Type ($name) ne 'cipp-config' ) {
			$self->Error("CONFIG", "Objekt '$name' ist kein Config-Objekt");
			return 1;
		}
		$self->{used_configs}->{$name} = 1;
#		print STDERR "set used_config for '$name'\n";
	}

	my $throw = $$opt{throw};
	$throw ||= 'config';

	my $require;

	if ( not $apache_mod ) {
		$self->{output}->Write (qq{
		CIPP::Runtime::Read_Config("$back_prod_path/config/$name.config", "$$opt{nocache}");
		});
	} else {
		$self->{output}->Write (qq{
		my \$cipp_subr = \$cipp_apache_request->lookup_uri("$name");
		CIPP::Runtime::Read_Config (\$cipp_subr->filename, "$$opt{nocache}");
		});
	}
	

	return 1;
}


sub Process_Htmlquote {
#
# INPUT:	1. Options
#		2. Ende-Tag?
#
# OUTPUT:	1. Danach innerhalb eines PRINT-Statements?
#
	my $self = shift;
	my ($opt, $end_tag) = @_;

	$self->Check_Options ("HTMLQUOTE", "VAR", "HTMLVAR MY", $opt) || return 1;

	$$opt{var} = "\$".$$opt{var} if $$opt{var} !~ /^\$/;
	
	if ( defined $$opt{htmlvar} ) {
		$$opt{htmlvar} = "\$".$$opt{htmlvar} if $$opt{htmlvar} !~ /^\$/
	} else {
		( $$opt{htmlvar} = $$opt{var} ) =~ s/^\$(.*)$/\$html_$1/;
	}

	my $my_cmd = $$opt{my} ? 'my ' : '';
	
	$self->{output}->Write (
		"${my_cmd}$$opt{htmlvar}=CIPP::Runtime::HTML_Quote($$opt{var});\n"
	);

	return 1;
}


sub Process_Urlencode {
#
# INPUT:	1. Options
#		2. Ende-Tag?
#
# OUTPUT:	1. Danach innerhalb eines PRINT-Statements?
#
	my $self = shift;
	my ($opt, $end_tag) = @_;

	$self->Check_Options ("URLENCODE", "VAR", "ENCVAR MY", $opt) || return 1;

	$$opt{var} =~ s/^\$//;
	$$opt{encvar}="\$enc_".$$opt{var} if ! defined $$opt{encvar};
	$$opt{encvar} = '$'.$$opt{encvar} if $$opt{encvar} !~ /^\$/;
	$$opt{var} = '$'.$$opt{var};

	my $my_cmd = $$opt{my} ? 'my ' : '';

	$self->{output}->Write (
		qq{${my_cmd}$$opt{encvar}=CIPP::Runtime::URL_Encode($$opt{var});\n} );

	return 1;
}

sub Process_Foreach {
#
# INPUT:	1. Options
#		2. Ende-Tag?
#
# OUTPUT:	1. Danach innerhalb eines PRINT-Statements?
#
	my $self = shift;
	my ($opt, $end_tag) = @_;

	if ( $end_tag ) {
		$self->Check_Options ("/FOREACH", "", "", $opt) || return 1;
		$self->{output}->Write ("}\n");
		return 1;
	}

	$self->Check_Options ("FOREACH", "VAR LIST", "MY", $opt) || return 1;

	$$opt{var} = '$'.$$opt{var} if $$opt{var} !~ /^\$/;
	$self->{output}->Write ("my $$opt{var};\n") if $$opt{my};

	$self->{output}->Write("foreach $$opt{var} ($$opt{list}) {\n");

	return 1;
}

sub Process_Geturl {
#
# INPUT:	1. Options
#		2. Ende-Tag?
#
# OUTPUT:	1. Danach innerhalb eines PRINT-Statements?
#
	my $self = shift;
	my ($opt, $end_tag) = @_;

	$self->Check_Options ("GETURL", "NAME URLVAR", "*", $opt)
		 || return 1;

	my $name = $$opt{name};
	my $runtime = $$opt{runtime};

	my $apache_mod = $self->{apache_mod};

	delete $$opt{runtime} if $runtime;
	my $throw = $$opt{throw};
	delete $$opt{throw} if $throw;
	
	if ( not $runtime and not $apache_mod ) {
		if ( ! defined $self->Object_Exists($name) ) {
			$self->Error("GETURL", "Objekt '$name' existiert nicht");
			return 1;
		}
	}

	$$opt{urlvar}='$'.$$opt{urlvar} if $$opt{urlvar} !~ /^\$/;
	my $my_cmd = $$opt{my} ? 'my ' : '';

	my $object_url;
	
	if ( not $runtime and not $apache_mod ) {
		$object_url = $self->Get_Object_URL ($name);
		if ( ! defined $object_url ) {
			$self->Error("GETURL", "Objekt '$name' hat keine URL");
			return 1;
		}
		$self->{output}->Write ("${my_cmd}$$opt{urlvar}=qq{$object_url}");
	} else {
		if ( not $apache_mod ) {
			$self->{output}->Write (
			  qq{${my_cmd}$$opt{urlvar}=CIPP::Runtime::Get_Object_URL ("$name", "$throw")}
			);
		} else {
			$self->{output}->Write (
			  qq{${my_cmd}$$opt{urlvar}=qq{$name}}
			);
		}
	}

	# Zu übergebende Parameter in eine Liste schreiben
	my @val_list;
	my ($par, $val);

	# Zunächst mal die Angaben aus PARAMS einlesen

	if ( defined $$opt{params} ) {
		my @parlist = split (/\s*,\s*/, $$opt{params});
		while ( $par = shift @parlist ) {
			$val = $par;
			$par =~ s/^[\$\@]//;
			$val = '$'.$val if $val !~ /^[\$\@]/;
			push @val_list, "$val\t$par";
		}
	}

	# Dann zusätzliche benannte Parameter

	while ( ($par,$val) = each %{$opt} ) {
		next if	$par eq 'name' or $par eq 'urlvar' or
			$par eq 'params' or $par eq 'my';
		push @val_list, "$val\t$par";
	}

	# nun stehen in @val_list zwei tab delimited Einträge von
	# folgender Form
	#	1.	Zugewiesener Parameter
	#		wenn $ am Anfang: scalare Variable
	#		wenn @ am Anfang: Liste
	#		wenn weder $ noch @ am Anfang: konstanter String
	# 	2.	Name des Parameters für die URL
	# nun noch ein paar Syntaxchecks

	if ( not $runtime and not $apache_mod ) {
		my $target_object_type = $self->Get_Object_Type ($name);
		if ( $target_object_type ne 'cipp' && (scalar @val_list) ) {
			$self->Error ("GETURL", "Es können nur Parameter an ein ".
				      "CGI-Objekt übergeben werden");
			return 1;
		}
	}

	# URL generieren: wenn Parameter vorhanden: anhängen!

	if ( scalar @val_list ) {
		# Zunächst werden scalare Parameter in EINER Stringzuweisung 
		# generiert. Anschließend werden Arrayparameter dynamisch
		# zugewiesen.

		my $delimiter = "?";
		my $item;

		foreach $item (grep /^[^\@]/, @val_list) {
			($val, $par) = split ("\t", $item);
			$self->{output}->Write (
			    qq{.qq{${delimiter}$par=}.}.
			    qq{CIPP::Runtime::URL_Encode("$val")} );

			$delimiter = "&" if $delimiter ne "&";
		}
		$self->{output}->Write ( ";\n" );

		foreach $item (grep /^\@/, @val_list) {
			($val, $par) = split ("\t", $item);
			$self->{output}->Write (
				qq[{my \$cipp_tmp;\nforeach \$cipp_tmp ($val) {\n].
				qq[$$opt{urlvar}.="${delimiter}$par=".].
				qq[CIPP::Runtime::URL_Encode(\$cipp_tmp);\n].
				qq[}\n}\n] );

			$delimiter = "&" if $delimiter ne "&";
		}
	} else {
		$self->{output}->Write (";\n");
	}

	return 1;
}

sub Process_Form {
#
# INPUT:	1. Options
#		2. Ende-Tag?
#
# OUTPUT:	1. Danach innerhalb eines PRINT-Statements?
#
	my $self = shift;
	my ($opt, $end_tag) = @_;

	if ( $end_tag ) {
		$self->Check_Options ("/FORM", "", "", $opt) || return 1;
		$self->{output}->Write (q{print "</FORM>";}."\n");
		return 1;
	}

	$self->Check_Options ("FORM", "ACTION", "*", $opt)
		 || return 1;

	my $method;
	if ( defined $$opt{method} ) {
		$method = $$opt{method};
		delete $$opt{method};
	} else {
		$method = "POST";
	}

	# ACTION URL ermitteln
	my $name = $$opt{action};
	delete $$opt{action};

	if ( ! defined $self->Object_Exists ($name) ) {
		$self->Error ("FORM", "Object '$name' exisitiert nicht");
		return 1;
	}

	if ( not $self->{apache_mod} and $self->Get_Object_Type ($name) ne 'cipp' ) {
		$self->Error ("FORM", "Object '$name' ist kein CGI Objekt");
		return 1;
	}

	my $object_url = $self->Get_Object_URL ($name);

	my $code = qq{print qq[<FORM ACTION="$object_url" }.
		   qq{METHOD=$method};

	# alle restlichen Parameter werden als Optionen in das
	# FORM-Tag geschrieben

	my ($par, $val);
	while ( ($par,$val) = each %{$opt} ) {
		$par =~ tr/a-z/A-Z/;	# schöner so, sacht der Jörn
		$code .= qq[ $par="$val"];
	}

	$code .= ">\\n];\n";

	$self->{output}->Write($code);

	return 1;
}

sub Process_Img {
#
# INPUT:	1. Options
#		2. Ende-Tag?
#
# OUTPUT:	1. Danach innerhalb eines PRINT-Statements?
#
	my $self = shift;
	my ($opt, $end_tag) = @_;

	$self->Check_Options ("IMG", "SRC", "*", $opt)
		 || return 1;

	# SRC URL ermitteln
	my $name = $$opt{src};
	delete $$opt{src};

	my $object_url;
	if ( not $self->{apache_mod} ) {
		if ( ! defined $self->Object_Exists ($name) ) {
			$self->Error ("IMG", "Object '$name' exisitiert nicht");
			return 1;
		}

		if ( $self->Get_Object_Type ($name) ne 'cipp-img' ) {
			$self->Error ("IMG", "Object '$name' ist kein Bild-Objekt");
			return 1;
		}
		$object_url = $self->Get_Object_URL ($name);
	} else {
		$object_url = $name;
	}


	my $code = qq{print qq[<IMG SRC="$object_url"};

	# alle restlichen Parameter werden als Optionen in das
	# IMG-Tag geschrieben

	my ($par, $val);
	while ( ($par,$val) = each %{$opt} ) {
		$par =~ tr/a-z/A-Z/;	# schöner so, sacht der Jörn
		$code .= qq[ $par="$val"];
	}

	$code .= ">];\n";

	$self->{output}->Write($code);

	return 1;
}

sub Process_A {
#
# INPUT:	1. Options
#		2. Ende-Tag?
#
# OUTPUT:	1. Danach innerhalb eines PRINT-Statements?
#
	my $self = shift;
	my ($opt, $end_tag) = @_;

	if ( $end_tag ) {
		$self->Check_Options ("/A", "", "", $opt) || return 1;
		$self->{output}->Write (q{print "</A>";}."\n");
		return 1;
	}

	$self->Check_Options ("A", "HREF", "*", $opt)
		 || return 1;

	# HREF URL ermitteln
	my $name = $$opt{href};
	delete $$opt{href};

	my $label;
	if ( $name =~ /#/ ) {
		($name, $label) = split ("#", $name, 2);
	}

	if ( ! defined $self->Object_Exists ($name) ) {
		$self->Error ("A", "Object '$name' exisitiert nicht");
		return 1;
	}

	my $object_url = $self->Get_Object_URL ($name);

	if ( ! defined $object_url ) {
		$self->Error ("FORM", "Object '$name' hat keine URL");
		return 1;
	}

	my $code;
	if ( defined $label ) {
		$code = qq{print qq[<A HREF="$object_url#$label"};
	} else {
		$code = qq{print qq[<A HREF="$object_url"};
	}

	# alle restlichen Parameter werden als Optionen in das
	# A-Tag geschrieben

	my ($par, $val);
	while ( ($par,$val) = each %{$opt} ) {
		$par =~ tr/a-z/A-Z/;	# schöner so, sacht der Jörn
		$code .= qq[ $par="$val"];
	}

	$code .= ">];\n";

	$self->{output}->Write($code);

	return 1;
}

sub Process_Textarea {
#
# INPUT:	1. Options
#		2. Ende-Tag?
#
# OUTPUT:	1. Danach innerhalb eines PRINT-Statements?
#
	my $self = shift;
	my ($opt, $end_tag) = @_;

	if ( $end_tag ) {
		$self->Check_Options ("/TEXTAREA", "", "", $opt) || return 1;
		$self->{output}->Write (q[}); print "</TEXTAREA>";]."\n");
		return 1;
	}

	my $options = '';
	my ($par, $val);
	while ( ($par,$val) = each %{$opt} ) {
		$par =~ tr/a-z/A-Z/;	# schöner so, sacht der Jörn
		$options .= qq[ $par="$val"];
	}

	$self->{output}->Write (
		qq[print qq{<TEXTAREA$options>},CIPP::Runtime::HTML_Quote (qq{]
	);
	
	return -1;
}


sub Process_Sub {
#
# INPUT:	1. Options
#		2. Ende-Tag?
#
# OUTPUT:	1. Danach innerhalb eines PRINT-Statements?
#
	my $self = shift;
	my ($opt, $end_tag) = @_;

	if ( $end_tag ) {
		$self->Check_Options ("/SUB", "", "", $opt) || return 1;
		$self->{output}->Write ("}\n");
		return 1;
	}

	$self->Check_Options ("SUB", "NAME", "", $opt)
		 || return 1;

	$self->{output}->Write (
		qq[sub $$opt{name} {\n]
	);
	
	return -1;
}


sub Process_Hiddenfields {
#
# INPUT:	1. Options
#		2. Ende-Tag?
#
# OUTPUT:	1. Danach innerhalb eines PRINT-Statements?
#
	my $self = shift;
	my ($opt, $end_tag) = @_;

	$self->Check_Options ("HIDDENFIELDS", "", "*", $opt)
		 || return 1;

	# Zu übergebende Parameter in eine Liste schreiben
	my @val_list;
	my ($par, $val);

	# Zunächst mal die Angaben aus PARAMS einlesen

	if ( defined $$opt{params} ) {
		my @parlist = split (/\s*,\s*/, $$opt{params});
		while ( $par = shift @parlist ) {
			$val = $par;
			$par =~ s/^[\$\@]//;
			$val = '$'.$val if $val !~ /^[\$\@]/;
			push @val_list, "$val\t$par";
		}
	}

	# Dann zusätzliche benannte Parameter

	while ( ($par,$val) = each %{$opt} ) {
		next if $par eq 'params';
		push @val_list, "$val\t$par";
	}

	# nun stehen in @val_list zwei tab delimited Einträge von
	# folgender Form
	#	1.	Zugewiesener Parameter
	#		wenn $ am Anfang: scalare Variable
	#		wenn @ am Anfang: Liste
	#		wenn weder $ noch @ am Anfang: konstanter String
	# 	2.	Name des Parameters für die URL

	# nun noch ein paar Syntaxchecks

	if ( !(scalar @val_list) ) {
		$self->Error ("HIDDENFIELDS", "Keine Parameter angegeben");
		return 1;
	}

	# Formularfelder generieren

	# Zunächst werden scalare Parameter generiert. Anschließend werden
	# die Felder für Arrayparameter dynamisch erstellt.

	my $item;

	foreach $item (grep /^[^\@]/, @val_list) {
		($val, $par) = split ("\t", $item);
		$self->{output}->Write (
		    qq[print qq{].
		    qq[<INPUT TYPE="HIDDEN" NAME="$par" VALUE="}.].
		    qq[CIPP::Runtime::Field_Quote(qq{$val}).qq{">\\n};\n] );
	}

	foreach $item (grep /^\@/, @val_list) {
		($val, $par) = split ("\t", $item);
		$self->{output}->Write (
		    qq[{my \$cipp_tmp;\nforeach \$cipp_tmp ($val) {\n].
		    qq[print qq{<INPUT TYPE="HIDDEN" NAME="$par" ].
		    qq[VALUE="}.CIPP::Runtime::Field_Quote(qq{\$cipp_tmp}).].
		    qq[qq{">\\n};\n].
		    qq[}\n}\n] );
	}

	return 1;
}

sub Process_Input {
#
# INPUT:	1. Options
#		2. Ende-Tag?
#
# OUTPUT:	1. Danach innerhalb eines PRINT-Statements?
#
	my $self = shift;
	my ($opt, $end_tag) = @_;

	$self->Check_Options ("INPUT", "", "*", $opt) || return 1;

	my $code = qq[print qq{<INPUT];

	my ($par, $val);
	while ( ($par,$val) = each %{$opt} ) {
		if ( $par eq 'value' ) {
			$code .= qq[ VALUE="}.CIPP::Runtime::Field_Quote].
		   		 qq[(qq{$$opt{value}}).qq{"];
		} else {
			$par =~ tr/a-z/A-Z/;	# schöner so, sacht der Jörn
			$code .= qq[ $par="$val"];
		}
	}

	$code .= ">};\n";

	$self->{output}->Write($code);

	return 1;
}

sub Process_Imgurl {
# ACHTUNG: OBSOLET
#	   WRAPPER UM Process_Geturl
#
# INPUT:	1. Options
#		2. Ende-Tag?
#
# OUTPUT:	1. Danach innerhalb eines PRINT-Statements?
#
	my $self = shift;
	my ($opt, $end_tag) = @_;

	return $self->Process_Geturl($opt, $end_tag);
}

sub Process_Cgiurl {
# ACHTUNG: OBSOLET
#	   WRAPPER UM Process_Geturl
#
# INPUT:	1. Options
#		2. Ende-Tag?
#
# OUTPUT:	1. Danach innerhalb eines PRINT-Statements?
#
	my $self = shift;
	my ($opt, $end_tag) = @_;

	return $self->Process_Geturl($opt, $end_tag);
}

sub Process_Docurl {
# ACHTUNG: OBSOLET
#	   WRAPPER UM Process_Geturl
#
# INPUT:	1. Options
#		2. Ende-Tag?
#
# OUTPUT:	1. Danach innerhalb eines PRINT-Statements?
#
	my $self = shift;
	my ($opt, $end_tag) = @_;

	return $self->Process_Geturl($opt, $end_tag);
}

sub Process_Cgiform {
# ACHTUNG: OBSOLET
#	   WRAPPER UM Process_Form
#
# INPUT:	1. Options
#		2. Ende-Tag?
#
# OUTPUT:	1. Danach innerhalb eines PRINT-Statements?
#
	my $self = shift;
	my ($opt, $end_tag) = @_;

	$$opt{action} = $$opt{name};

	if ( defined $$opt{formname} ) {
		$$opt{name} = $$opt{formname};
		delete $$opt{formname};
	} else {
		delete $$opt{name};
	}

	return $self->Process_Form($opt, $end_tag);
}


sub Process_Interface {
#
# INPUT:	1. Options
#		2. Ende-Tag?
#
# OUTPUT:	1. Danach innerhalb eines PRINT-Statements?
#
	my $self = shift;
	my ($opt, $end_tag) = @_;

	$self->Check_Options ("INTERFACE", "", "INPUT OPTIONAL", $opt) || return 1;

	push @{$self->{cgi_input}}, split(/\s*,\s*/, $$opt{input});

	if ( defined $$opt{optional} ) {
		push @{$self->{cgi_optional}}, split (/\s*,\s*/, $$opt{optional});
	}

	return 1;
}


sub Process_Incinterface {
#
# INPUT:	1. Options
#		2. Ende-Tag?
#
# OUTPUT:	1. Danach innerhalb eines PRINT-Statements?
#
	my $self = shift;
	my ($opt, $end_tag) = @_;

	$self->Check_Options ("INCINTERFACE", "",
			      "INPUT OPTIONAL NOINPUT OUTPUT NOOUTPUT NOQUOTE", $opt)
		or return 1;

#	if ( defined $$opt{noinput} ) {
#		$self->{inc_noinput} = 1;
#	}
#	if ( defined $$opt{nooutput} ) {
#		$self->{inc_nooutput} = 1;
#	}

	if ( not defined $$opt{input} and not defined $$opt{optional} ) {
		$self->{inc_noinput} = 1;
#		$self->Error ("INCINTERFACE",
#			      "Zusammen mit NOINPUT können keine Parameter deklariert werden");
#		return 1;
	}

	if ( not defined $$opt{output} ) {
		$self->{inc_nooutput} = 1;
#		$self->Error ("INCINTERFACE",
#			      "Zusammen mit NOOUTPUT können keine ".
#			      "Ausgabeparameter deklariert werden");
#		return 1;
	}


	my (@untyped, @unknown);
	
	if ( defined $$opt{input} ) {
		my ($var, $name);
		foreach $var (split(/\s*,\s*/, $$opt{input})) {
			($name = $var) =~ s/^[\$\@\%]//;
			push @untyped, $var if $name eq $var;
			$self->{inc_input}->{$name} = $var;
		}
	}

	if ( defined $$opt{optional} ) {
		my ($var, $name);
		foreach $var (split(/\s*,\s*/, $$opt{optional})) {
			($name = $var) =~ s/^[\$\@\%]//;
			push @untyped, $var if $name eq $var;
			$self->{inc_optional}->{$name} = $var;
		}
	}

	if ( defined $$opt{output} ) {
		my ($var, $name);
		foreach $var (split(/\s*,\s*/, $$opt{output})) {
			($name = $var) =~ s/^[\$\@\%]//;
			push @untyped, $var if $name eq $var;
			$self->{inc_output}->{$name} = $var;
		}
	}

	if ( defined $$opt{noquote} ) {
		my $var;
		
		foreach $var (split(/\s*,\s*/, $$opt{noquote})) {
			push @untyped, $var unless $var =~ /^[\$\@\%]/;
		     	my $var_name = $var;
			$var_name =~ s/^[\$\@\%]//;
			if ( defined $self->{inc_input}->{$var_name} or
			     defined $self->{inc_optional}->{$var_name} ) {
#			     or defined $self->{inc_output}->{$var_name} ) {
				$self->{inc_bare}->{$var_name} = 1;
#				print STDERR "inc_bare: $var_name\n";
			} else {
				push @unknown, $var;
			}
		}
		
	}
		
	if ( @untyped ) {
		$self->Error (
			"INCINTERFACE",
			"Folgende Parameter sind nicht typisiert: ".
			(join(", ", @untyped))
		);
		return 1;
	}

	if ( @unknown ) {
		$self->Error (
			"INCINTERFACE",
			"Folgende NOQUOTE Variablen sind ".
			"nicht bekannt: ".(join(", ", @unknown))
		);
		return 1;
	}

	return 1;
}


sub Process_Lib {
#
# INPUT:	1. Options
#		2. Ende-Tag?
#
# OUTPUT:	1. Danach innerhalb eines PRINT-Statements?
#
	my $self = shift;
	my ($opt, $end_tag) = @_;

	$self->Check_Options ("LIB", "NAME", "", $opt) || return 1;

	$self->{output}->Write("use $$opt{name};\n");

	return 1;
}


sub Process_Getparam {
#
# INPUT:	1. Options
#		2. Ende-Tag?
#
# OUTPUT:	1. Danach innerhalb eines PRINT-Statements?
#
	my $self = shift;
	my ($opt, $end_tag) = @_;

	$self->Check_Options ("GETPARAM", "NAME", "MY VAR", $opt) || return 1;

	my $var = $$opt{var};
	if ( not defined $var ) {
		$var = '$'.$$opt{name};
		$$opt{my} = 1;
	}

	if ( $var !~ /^[\$\@]/ ) {
		$self->Error (
			"GETPARAM",
			"Die Variable '$var' ist nicht mit \$ oder \@ typisiert!"
		);
		return 1;
	}

	my $my = $$opt{my} ? 'my' : '';

	$self->{output}->Write("$my $var = \$cipp_query->param(\"$$opt{name}\");\n");

	return 1;
}


sub Process_Getparamlist {
#
# INPUT:	1. Options
#		2. Ende-Tag?
#
# OUTPUT:	1. Danach innerhalb eines PRINT-Statements?
#
	my $self = shift;
	my ($opt, $end_tag) = @_;

	$self->Check_Options ("GETPARAMLIST", "VAR", "MY", $opt) || return 1;

	my $var = $$opt{var};

	if ( $var !~ /^[\@]/ ) {
		$self->Error (
			"GETPARAMLIST",
			"Die Variable '$var' muß eine Listenvariable sein!"
		);
		return 1;
	}

	my $my = $$opt{my} ? 'my' : '';

	$self->{output}->Write("$my $var = \$cipp_query->param();\n");

	return 1;
}

sub Process_Autoprint {
#
# INPUT:	1. Options
#		2. Ende-Tag?
#
# OUTPUT:	1. Danach innerhalb eines PRINT-Statements?
#
	my $self = shift;
	my ($opt, $end_tag) = @_;

	$self->Check_Options ("AUTOPRINT", "OFF", "", $opt) || return 1;

	$self->{mime_type} = "cipp/dynamic";

	return 1;
}

sub Process_Apredirect {
#
# INPUT:	1. Options
#		2. Ende-Tag?
#
# OUTPUT:	1. Danach innerhalb eines PRINT-Statements?
#
	my $self = shift;
	my ($opt, $end_tag) = @_;

	$self->Check_Options ("APREDIRECT", "URL", "", $opt) || return 1;

	my $url = $$opt{url};
	
	$self->{output}->Write (
		qq{\$cipp_apache_request->internal_redirect ("$url");}
	);

	return 1;
}

sub Process_Apgetrequest {
#
# INPUT:	1. Options
#		2. Ende-Tag?
#
# OUTPUT:	1. Danach innerhalb eines PRINT-Statements?
#
	my $self = shift;
	my ($opt, $end_tag) = @_;

	$self->Check_Options ("APGETREQUEST", "VAR", "MY", $opt) || return 1;

	my $var = $$opt{var};
	my $my = $$opt{my} ? 'my' : '';

	$self->{output}->Write("$my $var = \$cipp_apache_request;\n");

	return 1;
}


#---------------------------------------------------------------------------------

sub Resolve_Object_Source {
#
# INPUT:	1. Objekt-Name
#		2. Objekt-Typ
#
# OUTPUT:	1. vollstaendiger Pfad der Objekt-Sourcedatei
#

	my ($self, $object, $object_type) = @_;

	my $apache_mod = $self->{apache_mod};
	my $file;
	
	if ( not $apache_mod ) {
		my $project = $self->{project};
#		my ($project) = $object =~ /^([^\.]+)\./;

		return undef if ! defined $project or 
				! defined $self->{projects}->{$project};

		$file = $object;
		$file =~ s/^([^\.]*)\.//;	# Projektname rausschneiden
		$file =~ tr/\./\//;
		$file = $self->{projects}->{$project}."/$file";

		if ( defined $object_type ) {
			$file .= ".$object_type";
		}
	} else {
		my $subr = $apache_mod->lookup_uri ($object);
		$file = $subr->filename;
		$file = undef if not -e $file;
	}

	return $file;
}

sub Object_Exists {
#
# INPUT:	1. Objekt
#
# OUTPUT:	1	existiert
#		undef	existiert nicht
#
	my ($self, $object) = @_;

	return 1 if $self->{apache_mod};

	if ( defined $self->Get_Object_Type ($object) ) {
		return 1;
	} else {
		return undef;
	}
}

sub Get_Object_Type {
#
# INPUT:	1. Objekt
#
# OUTPUT:	1. Objekttyp
#
	my ($self, $object) = @_;

	die "Get_Object_Type im Apache-Modus aufgerufen" if $self->{apache_mod};

#	print "hallo?\n";

	my $file = $self->Resolve_Object_Source ($object, undef);
	my @filenames = <$file.*>;
	return undef if scalar @filenames != 1;
	$filenames[0] =~ /\.([^\.]+)$/;
	return $1;
}

sub Get_Object_URL {
#
# INPUT:	1. Objekt
#	      [ 2. =1  =>  eine absolute URL generieren ]
#
# OUTPUT:	1. URL
#		(undef wenn Objekt nicht exisitiert oder wenn es
#		 es dazu keine URL gibt)
#
# DESCRIPTION:	Es wird die URL des angegebenen Objekts zurückgegeben.
#		Dabei wird - wenn möglich - eine relative URL generiert.
#		Derzeit werden relative URL's generiert, wenn aus einer
#		statischen Seite (cipp-html) auf ein statisches Objekt
#		(cipp-html oder cipp-img) verwiesen wird.
#
	my ($self, $object, $absolute_url) = @_;

	# Als Apache-Modul gibt es keine Objektnamen. Hier werden immer
	# direkt URL's verwendet, so daß $object unverändert zurück-
	# gegeben wird
	
	if ( $self->{apache_mod} ) {
		return $object;
	}

	# Für normales CIPP geht's hier weiter

	my $object_type = $self->Get_Object_Type ($object);
	my $object_path = $object;

	$object_path =~ s!\.!/!g;
	$object_path =~ s![^\/]*!$self->{project}!;	# aktuelles Projekt
							# einsetzen
	
	my $object_url;

	if ( $object_type eq 'cipp' ) {
		$object_url = "\$CIPP_Exec::cipp_cgi_url/$object_path.cgi";
	} elsif ( $object_type eq 'cipp-html' ) {
		$object_url =  "\$CIPP_Exec::cipp_doc_url/$object_path.html";
	} elsif ( $object_type eq 'cipp-img' ) {
		my $ext = $self->Get_Image_Info($object);

		if ( ! defined $ext ) {
			$self->Error (
				"GETURL",
				"Konnte Bildobjekt '$object' nicht auflösen");
			return undef;
		}

		$object_url = "\$CIPP_Exec::cipp_doc_url/$object_path.$ext";
	}

	return undef if ! defined $object_url;

	if ( ! $absolute_url and 
	     $self->{result_type} eq 'cipp-html' and $object_type ne 'cipp') {
		my $from_object_url = $self->{object_url};
		my $to_object_url = $object_url;
		$from_object_url =~ s/\$CIPP_Exec::cipp_doc_url\///;
		$to_object_url =~ s/\$CIPP_Exec::cipp_doc_url\///;
		$object_url = Get_Rel_URL ($from_object_url, $to_object_url);
		$object_url = '$CIPP_Exec::cipp_doc_url'.$object_url
			if $object_url =~ /^\//;
	}

	return $object_url;
}


sub Get_Image_Info {
#
# INPUT:	1. Objektname
#
# OUTPUT:	1. Dateiendung
#
	my ($self, $object) = @_;

	my $filename = $self->Resolve_Object_Source
					($object, 'cipp-img');

	return (undef) if ! defined $filename;

	$filename =~ s!^(.*)/([^/]*)$!\1/.\2!;
	$filename .= ".info";

	return (undef) if ! open (INFO_FILE, $filename);

	my $imgurl = <INFO_FILE>;
	close INFO_FILE;

	$imgurl =~ /\.([^\.]+)$/;
	my $ext = $1;

	return ($ext);
}

#------------------------------------------------------------------------------

sub Get_Options {
#
# KEINE KLASSEN-METHODE
#
# INPUT:	1. Options als String
#
# OUTPUT:	1. Referenz auf Options-Hash
#		   oder	-1 : Syntaxfehler (illegale Komb von ")
#			-2 : doppelte Parameter
#
	my ($options) = @_;
	my %options;
	return \%options if $options eq '';

	my ($name_var, $name_flag, $value);

	$options =~ s/\\\"/\001/g;	# maskiere escapte Quotes
	$options =~ s/^\s+//;
	$options .= " ";

	while ( $options ne '' ) {
		# Suche 1. Parametername mit Zuweisung
		($name_var) = $options =~ /^([^\s=]+\s*=\s*)/;
		# Suche 1. Parametername ohne Zuweisung
		($name_flag) = $options =~ /^([^\s=]+)[^=]/;

		return -1 if ! defined $name_var && ! defined $name_flag;

		# Wenn ein " im Parameternamen vorkommt, muß ein Syntaxfehler
		# vorliegen

		return -1 if defined $name_var  && $name_var =~ /\"/;
		return -1 if defined $name_flag && $name_flag =~ /\"/;

		# Was wurde gefunden, Zuweisung oder Flag?
		if ( defined $name_var ) {
			# wir haben eine Zuweisung
			my $clear = quotemeta $name_var;
			$options =~ s/^$clear//;
			$name_var =~ s/\s*=\s*//;
			if ( $options =~ /^\"/ ) {
				# Parameter ist gequotet!
				($value) = $options =~ /^\"([^\"]*)/;
				$options =~ s/\"([^\"]*)\"\s*//;
			} else {
				# Parameter ist nicht gequotet!
				($value) = $options =~ /^([^\s]*)/;
				return -1 if $value eq '';
				$options =~ s/^([^\s]*)\s*//;
			}
			$value =~ tr/\001/\"/;
			$name_var =~ tr/A-Z/a-z/;
			if (defined $options{$name_var}) {
				return -2;
			} else {
				$options{$name_var} = $value;
			}
		} else {
			# wir haben ein Flag
			my $clear = quotemeta $name_flag;
			$options =~ s/^$clear\s*//;
			$name_flag =~ tr/A-Z/a-z/;
			$options{$name_flag} = 1;
		}
	}

	return \%options;
}


sub Read_Config_File {
#
# KEINE KLASSEN-METHODE
#
# INPUT:	1. Dateiname der Konfigurationsdatei
#
# OUTPUT:	1. Referenz auf Hash mit Inhalt der Datei
#
	my ($file) = @_;

	open (CONFIG, "$file") || return undef;

	my (%config, $key, $val);

	while (<CONFIG>) {
		chop;
		next if $_ eq '';
		($key, $val) = split ("\t", $_);
		$config{$key} = $val;
	}

	close CONFIG;

	return \%config;
}


sub Get_Rel_URL {
#
# INPUT:        1. Von-URL
#               2. Nach-URL
#
# OUTPUT:       1. relative URL
#
	my ($from, $to) = @_;

	$from =~ s/\/([^\/]*)$//;
	$to =~ s/\/([^\/]*)$//;
	my $to_file = $1;

	my @from = split ("/", $from);
	my @to = split ("/", $to);

	my ($f,$t);

	while ( $f eq $t ) {
		$f=shift(@from);
		$t=shift(@to);
		last if !defined $f or !defined $t;
	}

	if ( $f ne $t ) {
		unshift @from, $f if defined $f;
		unshift @to, $t if defined $t;
	}

	my $url = ("../" x scalar(@from)).join("/",@to).
		  (scalar (@to) > 0 ? '/':'').$to_file;

	return $url;
}

1;
__END__

=head1 NAME

CIPP - CgI Perl Preprocessor

=head1 SYNOPSIS

 use CIPP;
 my $CIPP = new CIPP ( @params );
 
 # @params are too complex for a synopsis

 $CIPP->Preprocess;

=head1 DESCRIPTION

CIPP is a perl module for translating CIPP sources to pure perl
programs. CIPP defines a HTML embedding language called CIPP
which has powerful features for CGI and database developers.
Many standard CGI- and database operations (and much more)
are covered by CIPP, so the developer has no need to code
them again and again.

CIPP is useful in two ways. One aproach is to let CIPP generate
standalone CGI scripts, which only need a little environment to
run (some configuration files). If you want to use CIPP in this
way: there is a complete development environment called spirit
which supports you in many ways, to develop such CGI programms
with CIPP. spirit can be downloaded from CPAN, but is only free
for non commercial usage.

The second is to use the Apache::CIPP_Handler module. This module
defines an Apache request handler for CIPP sources, so they will
be executed in an Apache environment on the fly, with a two-level
cache and great performance. The Apache::CIPP_Handler module is free
software.

=head1 CIPP LANGUAGE REFERENCE

The documentation of the language defined by CIPP can be
downloaded from CPAN as an extra package. This is usefull, because
the format of the documentation is PDF and the file has more
than 500kb. Also not every modification of CIPP leads to modification
of the documentation.

=head1 PUBLIC METHODS

The following description of the methods is currently in german
only. We will provide english documentation in future.

 $CIPP = new CIPP ($input, $output, $projects_file, $database_file,
		  $mime_type, $default_db, $call_path,
		  $skip_header_line, $debugging
		  [, $result_type ] [, $use_strict] [, $reintrant]
		  [, $apache_mod ], [, $spirit_project ] );

	$input		Dateiname oder Filehandle-Referenz oder
			Scalar-Referenz fuer Output
	$output		Dateiname oder Filehandle-Referenz oder
			Scalar-Referenz fuer Output
	$projects_file	Dateiname der Projekt-Konfigurationsdatei
	$database_file	Dateiname der Datenbank-Konfigurationsdatei
	$mime_type	Mime-Type der zu generierenden Seite
			= "cipp/dynamic" wenn Seite selber den HTTP-
			  Header ausgibt
	$default_db	Name der Datenbank, auf die defaultmaessig
			zugegriffen werden soll. Darf undef sein,
			dann werden SQL Befehle ohne Angabe einer
			Datenbank als Fehler gemeldet
	$call_path	Auflistung der Macros ueber die diese
			CIPP-Quelle aufgerufen wurde, mit : getrennt.
			Muß bei erstem Aufruf weggelassen werden bzw.
			leer sein
     $skip_header_line	Wenn dieser Parameter gesetzt ist,
			wird beim Einlesen eines CIPP Sources
			der Anfang solange ueberlesen, bis der Inhalt
			von $skip_header_line als einziges in
			der Zeile steht.
	$debugging	wenn 1, dann werden im erzeugten Perl-Code
			entsprechende Remarks erzeugt, aus denen
			der Perl-Interpreter bei Laufzeitfehlern
			die dem CIPP-Originaltext entsprechednen
			Zeilennummern generieren kann.
	$result_type	Typ des Dokumentes, was durch das Preprocessing
			erstellt werden soll:
			'cipp'	    : CIPP-CGI-Programm (Default)
			'cipp-html' : statische HTML Seite
			Wenn 'cipp-html' angegeben wird, werden
			URL's auf statische Seiten relativ ausgegeben
	$use_strict	soll 'use strict' generiert werden oder nicht
	$reintrant	soll reintranter Code generiert werden oder nicht
	$apache_mod	true, wenn Einsatz als Apache-Modul
	$project	Das Project, in dem sich das zu bearbeitende
			Objekt befindet.

 $status = $CIPP->Get_Init_Status();
	liefert	0 : Fehler beim Initialisieren
		1 : OK

 $CIPP->Preprocess();
	Uebersetzt die CIPP-Quelle nach Perl 

 $CIPP->Set_Write_Script_Header($on)
	$on		1 = Perl-Header wird geschrieben (zum Einbinden
			    von Libraries etc.)
			0 = Perl-Header wird nicht geschrieben, d.h.
			    es wird NUR der CIPP-Code 1:1 uebersetzt

 $CIPP->Set_Print_Content_Type ($on)
	$on		1 = Content-Type wird vom generierten Perl
			    Script ausgegeben
			0 = Content-Type wird vom generierten Perl
			    Script nicht ausgegeben

	Wirkt sich nur aus, wenn Write_Script_Header eingeschaltet
	ist.

 $status = $CIPP->Get_Preprocess_Status();
	- liefert 0, wenn Fehler aufgetreten sind
	- liefert 1, wenn keine Preprocessorfehler aufgetreten sind

 $status = $CIPP->Set_Preprocess_Status();
	Setzt den Status.

 $array_ref = $CIPP->Get_Messages();
	Liefert Preprocessor-Meldungen als Referenz auf
	ein Array, dessen Elemente folgendes Format haben:
		Aufrufpfad <TAB> Zeilennummer <TAB> Meldung

 $hash_ref = $CIPP->Get_Used_Macros();
	Liefert eine Hash-Referenz mit den Namen der Macros als Key,
	die von der uebersetzten Seite eingebunden werden. Liefert
	undef, wenn Methode vor Preprocess() aufgerufen wird oder keine
	Macros benutzt wurden

 $hash_ref = $CIPP->Get_Used_Images();
	Liefert eine Hash-Referenz mit den Namen der Bilder als Key,
	die von der uebersetzten Seite eingebunden werden. Liefert
	undef, wenn Methode vor Preprocess() aufgerufen wird oder keine
	Bilder benutzt wurden

 $hash_ref = $CIPP->Get_Used_Databases();
	Liefert eine Hash-Referenz mit den Namen der von der Seite
	benutzten Datenbanken als Key. Liefert undef, wenn Methode vor
	Preprocess() aufgerufen wird oder keine DB's benutzt wurden

 $hash_ref = $CIPP->Get_Used_Configs();
	Liefert eine Hash-Referenz mit den Namen der von der Seite
	benutzten Konfigurationen als Key. Liefert undef, wenn Methode
	vor Preprocess() aufgerufen wird oder keine Configs benutzt
	wurden

=head1 PRIVATE METHODS

 $hash_ref = $CIPP->Get_Include_Inputs();
	Liefert eine Listen-Referenz mit den Namen der von dem Include
	deklarierten MUSS-Input Parametern.

 $hash_ref = $CIPP->Get_Include_Optionals();
	Liefert eine Listen-Referenz mit den Namen der von dem Include
	deklarierten optionalen Input Parametern.

 $CIPP->Add_Message ($message, [$line] );
	Haengt Meldung $message an das Meldungs-Array an. Wenn $line
	nicht angegeben wird, wird die aktuelle Zeilennummer eingesetzt,
	sonst die uebergebene.

 $CIPP->Error ($tag, $message, [$line] );
	Schreibt $message und $tag in Meldungs-Array und setzt
	Preprocess_Status auf 0. Wenn eine Zeilennummer ($line)
	angegeben wird diese in die Fehlermeldung eingesetzt, ansonsten
	die aktuelle Zeilennummer

 $CIPP->Check_Options ($tag, $must_options, $valid_options, $hash_ref);
	Prueft die Optionen eines Tags auf Korrektheit.
	Es muessen alle in $must_options aufgefuehrten Parameter
	vorkommen. Es duerfen keine anderen als in $valid_options
	aufgefuehrten Parameter vorkommen. Wenn in $valid_options
	ein * steht, wird diese Pruefung nicht vorgenommen.
	Im Fehlerfalle wird 0 zurueckgegeben, sonst 1.

 $CIPP->Check_Nesting ($tag, $end_tag);
	Prueft, ob das uebergebene $tag an dieser Stelle syntaktisch,
	bzw. von der Schachtelung her, korrekt ist. Ist $end_tag
	gesetzt, wird geprueft ob das Schließen des uebergebenen Tags
	an dieser Stelle korrekt ist.
	Im Fehlerfalle wird eine entsprechende Fehlermeldung in das
	Meldungs-Array 	geschrieben und 0 zurueckgegeben. Ist alles
	korrekt, wird 1 zurueckgegeben.

 $CIPP->Generate_CGI_Code
	Generiert ggf. Script-Header, der u.a. fuer das Importieren
	der via CGI uebergebenen Eingabeparameter sorgt.
	Es wird keine Ausgabe generiert, wenn das Flag
	$CIPP->{write_script_header} nicht gesetzt ist.
	Der Code wird direkt in die Zieldatei geschrieben.

 $CIPP->Generate_Database_Code
	Generiert Code zum Initialiseren und Beenden von Datenbank-
	verbindungen, wenn es Datenbank-Befehle in der Seite gibt.
	Der Code wird direkt in die Zieldatei geschrieben. Die
	Methode darf NICHT VOR Generate_CGI_Header() aufgerufen
	werden.

 $CIPP->Skip_Header ()
	List solange von der Eingabequelle, bis
	$CIPP->{skip_header_line} gefunden wurde. Der Zeilen-
	zaehler der Eingabequelle wird auf 0 gesetzt.

 $object_type = $CIPP->Get_Object_Type ($object)
	Gibt den Typ des übergebenen $object zurück. Wenn dieser
	nicht eindeutig sein sollte, wird undef zurückgegeben.

 $object_path = $CIPP->Resolve_Object_Source ($object [, $object_type])
	Ermittelt aus dem abstrakten Objektnamen $object und
	dessen Typ $object_type den absoluten vollstaendigen
	Dateinamen im src-Zweig. $object_type darf auch weggelassen
	werden, dann wird keine Endung beim Dateinamen generiert.
	Liefert undef wenn der Projektanteil des Objektnames
	nicht bekannt ist.
	ES WIRD NICHT GEPRUEFT, OB DIE DATEI EXISTIERT!

 $url = $CIPP->Get_Object_URL ($object)
	Gibt die URL des Objektes zurück, wenn es eine hat. Gibt
	undef zurück, wenn das Objekt nicht existiert, oder wenn
	es keine URL hat.

 ($url, $ext) = $CIPP->Get_Image_Info ($object)
	Gibt Bildinformationen zu $object zurück. $url enthält
	die URL und $ext die Dateiendung des Bildes. $url ist
	undef, wenn das Bild nicht exisitiert oder $object nicht
	vom Type 'cipp-img' ist.

 \$html_formatted_source_code = $CIPP->Format_Debugging_Source (e)
	Gibt HTML formatierten CIPP-Quellcode zurück. Dabei werden
	die in der Instanz festgehaltenen Fehlermeldungen eingearbeitet
	und hervorgehoben.


=head1 AUTHOR

Jörn Reder, joern@dimedis.de

=head1 COPYRIGHT

Copyright 1997-1999 dimedis GmbH, All Rights Reserved

This library ist free software; you can redistribute it and/or modify
it under the same terms as Perl itself.

=head1 SEE ALSO

perl(1), Apache::CIPP_Handler(3pm)
