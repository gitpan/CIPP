# $Id: CIPP.pm,v 1.58 2001/03/07 16:50:14 joern Exp $

# TODO
#
# - bei General Exception pr¸fen ob HTTP Header schon generiert

package CIPP;

use strict;
use vars qw ( $INCLUDE_SUBS $VERSION $REVISION );

$VERSION = "2.28";
$REVISION = q$Revision: 1.58 $; 
$INCLUDE_SUBS = 0;

use Config;
use Carp;
use FileHandle;
use File::Basename;
use CIPP::InputHandle;
use CIPP::OutputHandle;
use CIPP::DB_DBI;

my %INCLUDE_CACHE;	# Cache f¸r Include CIPP Objekte

# alle Tags, die nicht geschlossen werden
$CIPP::cipp_single_tags = undef;
$CIPP::cipp_single_tags =
	"|else|elsif|include|log|throw|autocommit".
	"|execute|dbquote|commit|rollback|my|savefile|config".
	"|htmlquote|urlencode|hiddenfields|img|dump".
	"|input|geturl|interface|lib|incinterface|getparam|getparamlist".
	"|getdbhandle|autoprint|!autoprint|apredirect|apgetrequest|exit|use|require".
	"|!profile".
# aus Kompatibilt‰tsgr¸nden
	"|imgurl|cgiurl|docurl|cgiform|";

# alle Tags, die wieder geschlossen werden muessen
$CIPP::cipp_multi_tags  =
	"|if|var|do|while|perl|sql|try|catch|block|foreach".
	"|form|a|textarea|sub|module|html|select|option|!httpheader|#|!#|";

# Hash-Array fuer alle Tags, als Value wird der Name der behandelnden
# Methode eingetragen
%CIPP::tag_handler = (
		"perl",		"Process_Perl",
		"html",		"Process_Html",
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
		"select",	"Process_Select",
		"option",	"Process_Option",
		"textarea",	"Process_Textarea",
		"a",		"Process_A",
		"interface",	"Process_Interface",
		"lib",		"Process_Lib",
		"incinterface",	"Process_Incinterface",
		"getparam",	"Process_Getparam",
		"getparamlist",	"Process_Getparamlist",
		"getdbhandle",	"Process_Getdbhandle",
		"autoprint",	"Process_Autoprint",
		"!autoprint",	"Process_Autoprint",
		"apredirect",	"Process_Apredirect",
		"apgetrequest",	"Process_Apgetrequest",
		"sub",		"Process_Sub",
		"exit",		"Process_Exit",
		"module",	"Process_Module",
		"use",		"Process_Use",
		"require",	"Process_Require",
		"dump",		"Process_Dump",
		"!profile",	"Process_Profile",
		"!httpheader",	"Process_Httpheader",
		"!#",		"Process_Comment",
		"#",		"Process_Comment",
# aus Kompatiblit‰tsgr¸nden
		"imgurl",	"Process_Imgurl",
		"cgiurl",	"Process_Cgiurl",
		"docurl",	"Process_Docurl",
		"cgiform",	"Process_Cgiform"
);

# requl‰rer Ausdruck zum URL Codieren
$CIPP::URL_Encode_Expression = undef;
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
	    $project, $use_inc_cache, $lang) = @_;

	# Include Subroutine Feature einschalten, wenn gefordert
	if ( $INCLUDE_SUBS ) {
		$CIPP::tag_handler{incinterface} = "Process_Incinterface_Sub";
		$CIPP::tag_handler{include}      = "Process_Include_Sub";
	}

	# Defaults setzen
	$result_type ||= 'cipp';
	$lang ||= 'EN',

	# Spracheinstellungen laden
	do "CIPP/Lang$lang.pm";

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
			"project" => $project,
			"use_inc_cache" => $use_inc_cache,
			"perl_interpreter_path" => $Config{'perlpath'},
			"lang" => $lang,
			"profile" => undef,
			"context_stack" => []
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
	}

	my $blessed = bless $self, $type;

	my $me = $call_path;
	($me) = $me =~ /^([^:\[]+)/;

	$self->{object_url} = $blessed->Get_Object_URL ($me);

	if ( $self->{init_status} && $skip_header_line ) {
		$blessed->Skip_Header();
	}

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

sub Get_Used_Modules {
	my $self = shift;
	return undef if ! $self->{init_status};

	return $self->{used_modules};
}

sub Get_Direct_Used_Objects {
	my $self = shift;
	return undef if ! $self->{init_status};

	return $self->{direct_used_objects};
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

sub Get_Module_Name {
	my $self = shift;
	
	return undef if ! $self->{init_status};

	return $self->{module_name};
}

sub Add_Message {
	my $self = shift;
	return undef if ! $self->{init_status};

	my ($message, $line) = @_;

	$line ||= $self->{input}->Get_Line_Number();

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

sub ErrorLang {
	my $self = shift;
	
	my ($tag, $key, $par_lref, $line) = @_;
	
	my $message;
	if ( $par_lref ) {
		$message = sprintf ($CIPP::Lang::msg{$key}, @{$par_lref});
	} else {
		$message = $CIPP::Lang::msg{$key};
	}
	
	$message ||= "ERROR MESSAGE IS MISSING: $key";
	
	$self->Error ($tag, $message, $line);
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
		$self->ErrorLang ($tag, 'missing_options', [$must_options]);
	}
	if ( $illegal ne '' ) {
		$valid_options =~ s/\s$//;
		$valid_options =~ s/\s/,/g;
		$illegal =~ tr/a-z/A-Z/;
		$self->ErrorLang ($tag, 'illegal_options', [$illegal]);
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

			$self->ErrorLang ("ELSE", 'else_alone');
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

			$self->ErrorLang ("ELSIF", 'else_alone');
			return 0;
		}
                
		# f¸r alle MULTI-Tags, Schachtelungs-Array setzen

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
			$self->ErrorLang ("/$tag", 'no_block_command');
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
			$self->ErrorLang ($tag, 'wrong_nesting', ["<?/$last_tag>", "<?$tag>"]);

			return 0;
		}
		if ( -1 == $$nest_index ) {
			# och noe, es gab nicht EIN EINZIGES Open-Tag, das
			# kann doch gar nicht richtig sein!

			$tag = "/$tag";
			$tag =~ tr/a-z/A-Z/;
			$self->ErrorLang($tag, 'close_without_start');

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
	
	# Sonderregelung f¸r CIPP Module: die brauchen so oder so ein 'use strict'
	# und ggf. Database_Code (egal ob $self->{write_script_header} gesetzt ist).

	if ( $self->{result_type} eq 'cipp-module' ) {
		if ( $self->{use_strict} ) {
			$self->{target}->Write ("use strict;\n");
		}
#		$self->Generate_Database_Code ();
		return;
	}
	
	return if ! $self->{write_script_header};

	my $apache_mod = $self->{apache_mod};
	
	$self->{target}->Write ("#!$self->{perl_interpreter_path}\n") if not $apache_mod;
	$self->{target}->Write ("package CIPP_Exec;\n");
	$self->{target}->Write (qq{\$cipp::back_prod_path="$self->{back_prod_path}";\n});
	$self->{target}->Write (qq[BEGIN{\$cipp::back_prod_path="$self->{back_prod_path}";}\n]);
	
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
		
		if ( $INCLUDE_SUBS ) {
			$self->{target}->Write (
				"use CIPP::Request;\n".
				'my $cipp_request_object = new CIPP::Request ($cipp_apache_request);'."\n"
			);
		}
	}
	
	if ( not $apache_mod ) {
#---
# The # sign after the BEGIN { below tells new.spirit, that
# this BEGIN block may not be stripped before syntax checking
# A bit fishy, but...
#---
		$self->{target}->Write (
q(
local @INC = @INC;
BEGIN {#
	if ( not $CIPP_Exec::_cipp_in_execute ) {
		$0 =~ m!^(.*)[/\\\\][^/\\\\]+$!;chdir $1;
	}
).qq[
	do "\$cipp::back_prod_path/config/cipp.conf";
	unshift (\@INC, "\$cipp::back_prod_path/cgi-bin");
	unshift (\@INC, "\$cipp::back_prod_path/lib");
	unshift (\@INC, \@CIPP_Exec::cipp_perl_lib_dir)
		if \@CIPP_Exec::cipp_perl_lib_dir;
}
]);
	}
	$self->{target}->Write (
qq[
my \$cipp_query;
if ( ! defined \$CIPP_Exec::_cipp_in_execute ) {
	use CIPP::Runtime 0.36;
	use CGI;
	package CIPP_Exec;
	\$cipp_query = new CGI;
	$package_import
}
]);

	$self->{target}->Write (
qq[
eval { # CIPP-GENERAL-EXCEPTION-EVAL
package CIPP_Exec;
]);

	# Datenbankcode generieren
	
	$self->Generate_Database_Code ();

	# HTTP Header

	$self->Generate_HTTP_Header_Code ();

	# explizites Importieren von CGI Parameter, wenn $cgi_input
	# angegeben wurde, sonst Importieren in den Namespace ¸ber
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
		 q[$CIPP_Exec::cipp_http_header_printed = 0;]."\n".
		qq[}; # CIPP-GENERAL-EXCEPTION-EVAL;]."\n".
		qq[end_of_cipp_program:]."\n".
		 q[my $cipp_general_exception = $@;]."\n"
	);

	if ( not $apache_mod ) {
		$self->{output}->Write (
			"die \$cipp_general_exception if \$cipp_general_exception ".
			"and \$CIPP_Exec::_cipp_in_execute;\n".
			"CIPP::Runtime::Exception(\$cipp_general_exception) if \$cipp_general_exception;\n"
		);
	} else {
		$self->{output}->Write (
			"die \$cipp_general_exception if \$cipp_general_exception;\n"
		);
	}
}

sub Generate_HTTP_Header_Code {
	my $self = shift;

	my $apache_mod = $self->{apache_mod};

	# Apache::CIPP does the HTTP header stuff
	return if $apache_mod;

	# Should a content-type be set?

	if ( $self->{print_content_type} and 
	     $self->{mime_type} ne 'cipp/dynamic' ) {
		$self->{target}->Write (
			"\$CIPP_Exec::cipp_http_header{'Content-type'} = ".
			"'$self->{mime_type}';\n"
		);
		
#		$self->{target}->Write (
#			"print \"Content-type: ".$self->{mime_type}.
#			"\\nPragma: no-cache\\n\\n\" if not \$CIPP_Exec::_cipp_no_http;\n");
#
#		$self->{target}->Write (
#			q{$CIPP_Exec::cipp_http_header_printed = 1;}."\n");
	}

	# did a <?!HTTPHEADER> command occur? Then insert the code.

	if ( $self->{http_header_perl_code} ) {
		$self->{target}->Write (
			"{\n".
			$self->{http_header_perl_code}.
			"}\n"
		);
	}

	# now produce the http header generation code

	if ( $self->{print_content_type} and
	     not ( $self->{mime_type} eq 'cipp/dynamic' and
	           not $self->{http_header_perl_code} ) ) {

		# But not, if we have 'cipp/dynamic' without any
		# <?!HTTPHEADER> tag, because otherwise the configured
		# default http header is produced, which is absolutely
		# wrong! The user expects, that *no* header is generated,
		# and that he has to produce the header himself.

		$self->{target}->Write (
			qq[# generate http header\n].
			qq[{\n].
			q[foreach my $cipp_http_header ( keys %CIPP_Exec::cipp_http_header ) {]."\n".
			q[  print "$cipp_http_header: $CIPP_Exec::cipp_http_header{$cipp_http_header}\\n";]."\n".
			q[  $CIPP_Exec::cipp_http_header_printed = 1;]."\n".
			q[}]."\n".
			q[print "\\n" if $CIPP_Exec::cipp_http_header_printed;]."\n".
			qq[}\n]
		);
	} else {
		$self->{target}->Write (
			qq{\n}.
			qq{# no header generation. Mime type "cipp/dynamic" is\n}.
			qq{# set and no <?!HTTPHEADER> occured\n\n}
		);
	}

	# print CIPP remark
	
	if ( $self->{mime_type} eq 'text/html' and not $apache_mod 
	     and not $self->{autoprint_off} ) {
		$self->{target}->Write ( 
			"print \"<!-- generated with CIPP ".
			$self->{version}."/$CIPP::REVISION, ".
			"(c) 1997-2001 dimedis GmbH, Cologne -->\\n\";\n");
	}
}


sub Generate_Database_Code {
	my $self = shift;
	return if ! $self->{init_status};
	return if ! defined $self->{used_databases};

	if ( $self->{result_type} eq 'cipp-module' ) {
		# Eines eines Moduls: 1 zur¸ckgeben
		$self->{output}->Write ( "\n}\n1;\n" );
		return;
	}

	my $code = qq[CIPP::Runtime::Close_Database_Connections();\n];
	
	my $apache_mod = $self->{apache_mod};
	
	my $db;
	foreach $db (keys %{$self->{used_databases}}) {
		
#		if ( $apache_mod ) {
#			# Parameter aus Apache-Config holen
#			$code .= qq{
#\$CIPP_Exec::cipp_db_${db}::data_source = \$cipp_apache_request->dir_config ("db_${db}_data_source");
#\$CIPP_Exec::cipp_db_${db}::user = \$cipp_apache_request->dir_config ("db_${db}_user");
#\$CIPP_Exec::cipp_db_${db}::password = \$cipp_apache_request->dir_config ("db_${db}_password");
#\$CIPP_Exec::cipp_db_${db}::autocommit = \$cipp_apache_request->dir_config ("db_${db}_auto_commit");
#};
#		}
		
		my $driver = $self->{db_driver}{$db};
		$driver =~ s/CIPP_/CIPP::/;
		
		return if not $driver;
		
		my $dbph = $driver->new(
			db_name => $db, apache_mod => $self->{apache_mod}
		);
		
		$code .= $dbph->Init;
	}

	# Ende des CGI Programms: schlieﬂen der Datenbankconnections
	$self->{target}->Write ( $code );

	$self->{output}->Write (
		qq[CIPP::Runtime::Close_Database_Connections();\n]
	);
}

sub Preprocess {
	my $self = shift;
	return undef if ! $self->{init_status};

	# Datenstrukturen zur Verfolgung der Schachtelung von CIPP-Tags

	$self->{nest_tag}[50] = "";	# Stack fuer CIPP-Tags
	$self->{nest_tag_line}[50] = 0;	# In welcher Zeile stand entsprechendes
					# CIPP-Tag
	$self->{nest_index} = -1;	# Aktueller Index in den beiden Arrays

	# Context-Stack initialisieren
	$self->{context_stack} = [ 'html' ];	# html = HTML Context
						# perl = <?PERL> Context
						# var  = <?VAR> Context
						# force_html = HTML Context durch <?HTML>
	# SQL Driver Stack initialisieren
	$self->{sql_driver_stack} = [];

	my $magic = $self->{magic};
	my $magic_reg = quotemeta $self->{magic};

	# Jetzt kann's losgehen, mit dem praeprozessieren (Wort des Jahres :)

	my $chunk = '';
	my $in_print_statement = 1;
	my ($found, $tag, $options, $end_tag, $error, $from_line, $to_line);

	$self->{gen_print} = $self->{mime_type} eq 'cipp/dynamic' ? 0 : 1;

	PREPROCESS: while ( 1 ) {

		# wenn als Mime-Type 'cipp/dynamic' angegeben wurde, wird kein HTTP
		# Header generiert und auch keine Print-Befehle. Darum muss sich
		# die Seite nun komplett selber kuemmern. Entsprechend wird das
		# Flag $gen_print gesetzt.
		#
		# Wir machen das f¸r jeden CIPP-Befehl, da sich dieser Zustand
		# w‰hrend der ‹bersetzung ‰ndern kann (=> <?AUTOPRINT>)
	
		my $gen_print = $self->{gen_print};

		$from_line = $self->{input}->Get_Line_Number()+1;
		$chunk = $self->{input}->Read_Cond($magic,1);
		$to_line = $self->{input}->Get_Line_Number();

		$found = ( $chunk =~ /$magic_reg$/ );

		my $context = $self->{context_stack}->
					[@{$self->{context_stack}}-1];

		if ( $found ) {
			# CIPP-Tag gefunden, Bereich davor verarbeiten
			$chunk =~ s/$magic_reg$//;	# Magic entfernen
			$chunk =~ s/\r//g;

			# gelesenen Block ausgeben, wenn wir nicht
			# in einem Kommentarblock sind

			$self->Chunk_Out (\$chunk, $in_print_statement,
					  $gen_print, $from_line)
				if $context ne 'comment';

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
				$self->ErrorLang($tag, 'gt_not_found');
				last;		# dann raus hier, mehr
						# kann nicht getan werden
			}

			# Ok, wir haben ein vollstaendiges Tag gefunden

			$end_tag = ($tag=~s/^\///);	# Ist es ein Ende-Tag?,
							# dann / entfernen und
							# dafuer $end_tag setzen
			
			# Wenn wir in einem Kommentarblock sind werden
			# nur Kommentarbefehle verarbeitet
			
			if ( $context eq 'comment' and $tag ne '!#' and $tag ne '#' ) {
				next PREPROCESS;
			}

			# Optionen rausholen, d.h. TAG-Bezeichner rausschneiden

			($options = $chunk) =~ s/^\s*[^\s]+\s*//;

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
				$self->ErrorLang
				   ($tag, 'tag_par_syntax_error');
			} elsif ( -2 == $opt ) {
				$tag = "/".$tag if $end_tag;
				$self->ErrorLang ($tag, 'double_tag_parameter');
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
						"\n\n# cippline $to_line ".'"'.
						$self->{call_path}.':&lt;?'.
						$big_tag.'>"'."\n" );
				}
				
				# Aufruf der entsprechenden Process_* Methode

				$in_print_statement =
					$self->$tag_method ($opt, $end_tag,
						$in_print_statement);
			}
		} else {
			# kein CIPP-Tag im Quelltext gefunden
			$chunk =~ s/\r//g;

			$self->Chunk_Out (\$chunk, $in_print_statement,
					  $gen_print, $from_line);
			last PREPROCESS;
		}
		
	}

	# Abschliessend pruefen, ob der Schachtelungsstack aufgeraeumt ist,
	# sprich: gibt es Tags, die nicht geschlossen wurden?

	if ( -1 != $self->{nest_index} ) {
		my $i;
		for ($i = 0; $i <= $self->{nest_index}; ++$i) {
			$self->ErrorLang (
				$self->{nest_tag}[$i],
				'close_missing',
				undef,
				$self->{nest_tag_line}[$i]
			);
		}
	} else {
		# Code fuer Header / Footer und Datenbank generieren
		$self->Generate_CGI_Code();

		# generierten Perl-Code in die Zieldatei schreiben
		$self->{target}->Write (${$self->{perl_code}});
	}

	# wenn <?AUTOPRINT> vorgekommen ist, muﬂ der Mime Type
	# nachtr‰glich noch auf cipp/dynamic gesetzt werden
	# Das darf erst jetzt gemacht werden, weil sonst evtl.
	# INCLUDES f‰lschlicherweise von cipp/dynamic ausgehen
	
	$self->{mime_type} = 'cipp/dynamic' if $self->{autoprint_off};

	# wie schaut's mit dem <?MODULE> Befehl aus?
	if ( $self->{result_type} eq 'cipp-module' and
	     not $self->Get_Module_Name ) {
		$self->ErrorLang (
			"MODULE",
			'module_missing'
		);
	}
}


sub Chunk_Out {
#
# INPUT:	1. Referenz auf Chunk
#		2. Befindet Parser sich in einem PRINT Statement
#		3. wie soll der Chunk ausgegeben werden:
#		   1	als print Befehl
#		   0	unver‰ndert
#		   -1	mit Escaping von } Zeichen (f¸r Variablenzuweisung)
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
		my $context = $self->{context_stack}->
					[@{$self->{context_stack}}-1];

		if ( $context eq 'html' or $context eq 'force_html' ) {
			if ( ($gen_print and $context eq 'html') or
			     $context eq 'force_html' ) {
				# HTML-Context: es wird ein print qq[] Befehl
				# generiert
				# ggf. Debugging-Code erzeugen
				$output->Write (
					"\n\n\n\n# cippline $from_line ".'"'.
					 $self->{call_path}.'"'."\n" );

				# Chunk muss via print ausgegeben werden
				$output->Write ("print qq[");
				$$chunk_ref =~ s/\[/\\\[/g;
				$$chunk_ref =~ s/\]/\\\]/g;
				$output->Write ($$chunk_ref);
				$output->Write ("];\n");
			}
		} elsif ( $context eq 'perl' ) {
			# <?PERL>Context
			# Chunk wird unveraendert uebernommen
			$output->Write ($$chunk_ref);
		} elsif ( $context eq 'var' ) {
			# <?VAR> Context
			# Chunk wird mit escapten } uebernommen
			$$chunk_ref =~ s/\}/\\\}/g;
			$output->Write ($$chunk_ref);
		} elsif ( $context eq 'comment' ) {
			# Hier machen wir nix.
		} else {
			die "Unknown context '$context'";
		}
	}
}

sub Format_Debugging_Source {
	my $self = shift;
	
	my $html = "";		# Scalar f¸r den HTML-Code

	my $ar = $self->Get_Messages;
	my $line;

	# Erstmal eine Liste der Fehler erzeugen, sp‰ter kommt dann
	# der Quellcode mit highlighting
	
	my $nr = 0;
	$html .= "<pre>\n";
	my %anchor;
	foreach my $err (@{$ar}) {
		my ($path, $line, $msg) = split ("\t", $err, 3);
		$path =~ /([^:]+)$/;
		my $name = $1;
		$path =~ s/:$name//;
		
		if ( not defined $anchor{"${name}_$line"} ) {
			$html .= qq{<a name="cipperrortop_${name}_$line"></a>};
			$anchor{"${name}_$line"} = 1;
		}

		$html .= qq{<a href="#cipperror_${name}_$line">};
		$html .= "$err";
		$html .= "</a>\n";
		++$nr;
	}
	$html .= "</pre>\n";

	# Nun alle betroffenen Objekte extrahieren und dabei die Fehlermeldungen
	# in ein Hash umschichten
	my %object;
	my %error;
	my @object;
	
	my $i_have_an_error = undef;
	foreach $line (@{$ar}) {
		my ($path, $line, $msg) = split ("\t", $line, 3);
		next if $line == -1;
		$path =~ /([^:]+)$/;
		my $name = $1;
		$path =~ s/:$name//;

		if ( $name and not defined $object{$name} ) {
			my $object_type;
			if ( not $self->{apache_mod} ) {
				$object_type = $self->Get_Object_Type ($name);
			}
			$object{$name} =
				$self->Resolve_Object_Source ($name, $object_type);
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
			s/>/&gt;/g;
			push @{$object_source{$object}}, $_;
		}
		close $fh;
	}
	
	# nun haben wir ein Hash von Listen mit den Quelltextzeilen
	$nr = 0;
	foreach $object (@object) {
		$html .= qq{<a name="object_$object"></a>};
		$html .= "<P><HR><FONT FACE=Helvetica><H1>$object</H1></FONT><P><PRE>\n";
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
				$html .= "\n";
				if ( $color eq 'red' ) {
					# error highlighting
					$html .= qq{<a name="cipperror_${object}_$i"></a>};
					$html .= qq{<B><a href="#cipperrortop_${object}_$i">}.
						 qq{<FONT COLOR=$color>$i\t}.
						 qq{$line</FONT></a></B>\n};
				} else {
					# include reference highlighting
					$html .= "<B><FONT COLOR=$color>$i\t$line</FONT></B>\n";
				}
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

sub Format_Perl_Errors {
	my $self = shift;

	my ($code_sref, $error_sref) = @_;

	my @errors = split (/\n/, $$error_sref);
	my @code = split (/\n/, $$code_sref);

	my $found_error;

	foreach my $error (@errors) {
		my ($line) = $error =~ m!\(eval\s+\d+\)\s+line\s+(\d+)!;
		next if not $line;

		my $i = $line+1;

		my $cipp_line = -1;
		my $cipp_call_path = "";

		$error =~ s/at\s+\(eval\s+\d+\)\s+/at /;
		$error =~ s/\,.*?chunk\s+\d+//;

		while ( $i > 0 ) {
			if ( $code[$i] =~ /^# cippline\s+(\d+)\s+"([^"]+)/ ) {
				$cipp_line = $1;
				$cipp_call_path = $2;
				$cipp_call_path =~ s/&lt;/</g;
				if ( $cipp_call_path =~ s/:(<.*)// ) {
					$error = "$1: $error";
				} else {
					$error = "HTML Block: $error";
				}
				last;
			}
			--$i;
		}

		push @{$self->{message}},
			$cipp_call_path."\t".$cipp_line."\t".$error;

		$found_error = 1;
	}

	if ( not $found_error ) {
		push @{$self->{message}},
			"\t0\t".$$error_sref;
	}

	return $self->Format_Debugging_Source;
}


# Unterroutinen f¸r die einzelnen CIPP-Befehle -----------------------------------

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
		# Kontext vom Stack poppen
		pop @{$self->{context_stack}};
		
		$self->Check_Options ("/PERL", "", "", $opt) || return 1;
		$self->{output}->Write ("}\n");
		return 1;
	}

	$self->Check_Options ("PERL", "", "COND", $opt) || return 0;

	$self->{output}->Write ("if ($$opt{cond}) ") if defined $$opt{cond};
	$self->{output}->Write ("{;");	# sonst gibt <?PERL><?/PERL> ohne
					# Inhalt einen Syntaxfehler

	push @{$self->{context_stack}}, 'perl';

	return 0;
}

sub Process_Html {
#
# INPUT:	1. Options
#		2. Ende-Tag?
#
# OUTPUT:	1. Danach innerhalb eines PRINT-Statements?
#
	my $self = shift;
	my ($opt, $end_tag) = @_;

	if ( $end_tag ) {
		# Kontext vom Stack poppen
		pop @{$self->{context_stack}};
		
		$self->Check_Options ("/HTML", "", "", $opt) || return 1;
		return 1;
	}

	$self->Check_Options ("HTML", "", "", $opt) || return 0;

	push @{$self->{context_stack}}, 'force_html';

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
		# Kontext vom Stack poppen
		pop @{$self->{context_stack}};

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
			$self->ErrorLang ("VAR", 'var_default_scalar');
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
			$self->ErrorLang ("VAR", 'var_invalid_type');
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
	$self->{output}->Write("$$opt{name}=".$quote_char);

	if ( $self->{var_quote} == -1 ) {
		push @{$self->{context_stack}}, 'var';
	} else {
		push @{$self->{context_stack}}, 'perl';
	}

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
	my ($opt, $end_tag, $in_print_statement) = @_;

	$self->Check_Options ("INCLUDE", "NAME", "*", $opt) || return 1;

	# Pruefen, ob rekursiver Aufruf vorliegt

	if ( $self->{call_path} =~ /:$$opt{name}\[/ ) {
		$self->ErrorLang (
			"INCLUDE", 'include_recursive',
			[ $$opt{name}, $self->{call_path} ]
		);
		return 1;
	}

	my $name = $$opt{name};
	delete $$opt{name};
	my $my = $$opt{'my'};
	delete $$opt{'my'};

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
		$self->ErrorLang ("INCLUDE", 'object_not_found', [$name]);
		return 1;
	}

	if ( ! -r $macro_file ) {
		$self->ErrorLang ("INCLUDE", 'include_not_readable', [$name, $macro_file]);
		return 1;
	}


	# Pr‰prozessor initialisieren

	my $code;	# Perl Code des Includes
	my $MACRO;	# CIPP Object f¸r Include

	my $need_to_preprocess = 1;
	
	# Schl¸ssel f¸r Include-Cache: Name des Objektes + Flag,
	# ob print Befehle generiert werden sollen oder nicht
	# (cipp/dynamic), da so jeweils unterschiedliche Versionen
	# des Includes entstehen.
	my $inc_cache_key = $name.($self->{gen_print}?"_with_print":"_without_print");
	
	if ( $self->{apache_mod} ) {
		$inc_cache_key .= "-".$ENV{SERVER_NAME};
	}
	
	if ( $self->{use_inc_cache} ) {
		# Cache ist eingeschaltet
		if ( exists $INCLUDE_CACHE{$inc_cache_key} ) {
			# unser Objekt ist im Cache, fein!
			$MACRO = $INCLUDE_CACHE{$inc_cache_key}->{cipp_object};
			$code  = ${$INCLUDE_CACHE{$inc_cache_key}->{code}};
			$need_to_preprocess = 0;
		}
	}

	if ( $need_to_preprocess ) {
		$MACRO = new CIPP
			($macro_file, \$code, $self->{projects},
			 $self->{db_driver}, $self->{mime_type},
			 $self->{default_db}, $self->{call_path}.
			 "[".$self->{input}->Get_Line_Number."]:".$name,
			 $self->{skip_header_line}, $self->{debugging},
			 "include", $self->{use_strict},
			 $self->{persistent}, $self->{apache_mod},
			 $self->{project}, $self->{use_inc_cache},
			 $self->{lang});

		# Profiling an Includes vererben?
		$MACRO->{profile} = 'deep' if $self->{profile} eq 'deep';

		# Haben wir schon <?!HTTPHEADER> gehabt?
		if ( exists $self->{http_header_perl_code} ) {
			$MACRO->{http_header_perl_code} = 1;
		}

		if ( ! $MACRO->Get_Init_Status ) {
			$self->ErrorLang ("INCLUDE", 'include_cipp_init');
			return 1;
		}

		# ‹bersetzen des Macros

		$MACRO->Set_Write_Script_Header (0);
		$MACRO->Preprocess ();
		
		# wenn Cache eingeschaltet: Cachen!
		
		if ( $self->{use_inc_cache} ) {
			$INCLUDE_CACHE{$inc_cache_key}->{cipp_object} = $MACRO;
			$INCLUDE_CACHE{$inc_cache_key}->{code} = \$code;
			# input File schliessen
			# (die werden sonst erst beim Script Ende
			# geschlossen, da kommt man schnell ans 'ulimit -n')
			$MACRO->{input} = undef;
		}
		
		# Wurde dort <?!HTTPHEADER> verwendet?
		if ( not exists $self->{http_header_perl_code} and
		         exists	$MACRO->{http_header_perl_code} ) {
			$self->{http_header_perl_code} =
				$MACRO->{http_header_perl_code};
		}
	}


	# Ist die ‹bergabe von Parametern verboten, es wurden aber
	# doch welche angegeben?
	
	if ( $MACRO->{inc_noinput} and scalar(keys %{$opt}) ) {
		$self->ErrorLang ("INCLUDE", 'include_no_in_par', [$name]);
		return 1;
	}
	if ( $MACRO->{inc_nooutput} and scalar(keys %{$var_output}) ) {
		$self->ErrorLang ("INCLUDE", 'include_no_out_par', [$name]);
		return 1;
	}
	

	# wenn eine Schnittstelle spezifiziert wurde,
	# ist sie auch eingehalten?

	my $param_must    = $MACRO->Get_Include_Inputs();
	my $param_opt     = $MACRO->Get_Include_Optionals();
	my $param_bare    = $MACRO->Get_Include_Bare();
	my $param_output  = $MACRO->Get_Include_Outputs();
	
	# Array f¸r fehlerhafte Parameter
	
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
	
	# Wurden unbekannte Eingabeparameter ¸bergeben?

	foreach my $i ( keys %{$opt} ) {
		next if defined $param_opt->{$i};
		next if defined $param_must->{$i};
		push @unknown_params, $i;
	}

	# Wurden unbekannte Ausgabeparameter angegeben
	
	if ( defined $param_output ) {
		my $i;
		foreach $i (keys %{$var_output}) {
			if ( not defined $param_output->{$i} ) {
				push @unknown_output, $i;
			}
		}
	}

	# Code f¸r die ¸bergebenen Parameter generieren

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

	# Wenn wir 'use strict' Code generieren sollen, m¸ssen nun noch
	# alle optionalen und Ausgabe-Parameter, die nicht ¸bergeben wurden,
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

	# Nun Code f¸r eventuelle Ausgabeparameter generieren
	
	my ($code_out_before, $code_out_after) = ('', '');
	
	my (@wrong_types, @equal_names);
		
	if ( defined $param_output ) {
		my ($name, $var);
		my @declare;
		while ( ($name, $var) = each %{$var_output} ) {
			if ( defined $param_output->{$name} ) {
				push @declare, $var;
				$code_if .= "my ".$param_output->{$name}.";\n";
				if ( $var eq $param_output->{$name} ) {
					push @equal_names, $var;
				}
				$code_out_after .= $var."=".$param_output->{$name}.";\n";
				if ( substr($var,0,1) ne substr($param_output->{$name},0,1) ) {
					my $type = substr($param_output->{$name},0,1);
					my $correct = $var;
					$correct =~ s/^./$type/;
					push @wrong_types, "$var. Richtig w‰re: $correct";
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
	my $config;
	if ( defined $MACRO->Get_Used_Configs() ) {
		while ( ($config, $foo) = each %{$MACRO->Get_Used_Configs()} ) {
			$self->{used_configs}{$config} = 1;
		} 
	}

	# Meldungsliste updaten
	# Zun‰chst Fehler bez¸glich der Schnittstelle
	
	if ( scalar(@missing_params) ) {
		my $i;
		foreach $i (@missing_params) {
			$self->ErrorLang ("INCLUDE", 'include_missing_in_par', [$i]);
		}
	}

	if ( scalar(@unknown_params) ) {
		my $i;
		foreach $i (@unknown_params) {
			$self->ErrorLang ("INCLUDE", 'include_unknown_in_par', [$i]);
		}
	}

	if ( scalar(@unknown_output) ) {
		my $i;
		foreach $i (@unknown_output) {
			$self->ErrorLang ("INCLUDE", 'include_unknown_out_par', [$i]);
		}
	}

	if ( scalar(@wrong_types) ) {
		my $i;
		foreach $i (@wrong_types) {
			$self->ErrorLang ("INCLUDE", 'include_wrong_out_type', [$i]);
		}
	}

	if ( scalar(@equal_names) ) {
		my $i;
		foreach $i (@equal_names) {
			$self->ErrorLang ("INCLUDE", 'include_out_var_eq_par', [$i]);
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

	
	# Ist Profiling eingeschaltet?
	if ( $self->{profile} ) {
		$code_out_before =
			$self->get_profile_start_code().
			$code_out_before;
		$code_out_after .=
			$self->get_profile_end_code (
				"INCLUDE", $name
			);
	}
	
	# Code ausgeben
	$self->{output}->Write (
		$code_out_before.
		"{\n".$code_if."{\n".$code.
		"}\n".
		$code_out_after.
		"}\n"
	);

	return $in_print_statement;
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
	my ($opt, $end_tag, $in_print_statement) = @_;

	if ( $end_tag ) {
		# wenn undef auf dem Stack liegt, war ein Syntaxfehler
		# fehler aufgetreten, dann braucht/kann auch kein Ende-Code
		# erzeugt werden
		my $dr = pop @{$self->{sql_driver_stack}};
		if ( defined $dr ) {
			$self->{output}->Write ($dr->End_SQL());
		}

		if ( $self->{profile} ) {
			$self->{output}->Write (
				$self->get_profile_end_code (
					"SQL", pop @{$self->{sql_profile_stack}}
				)
			);
		}
		return $in_print_statement;
	}

#	if ( defined $self->{driver_used} ) {
#		$self->ErrorLang ("SQL", 'sql_nest');
#		return 1;
#	}

	# erstmal auf dem Stack vermerken, evtl. treten noch
	# Fehler auf, der Stack muﬂ das SQL Statement aber schon
	# enthalten, sonst gibt's Probleme mit <?/SQL>
	push @{$self->{sql_driver_stack}}, undef;
	push @{$self->{sql_profile_stack}}, undef;

	$self->Check_Options (
		"SQL", "", 
		"SQL DB DBH VAR PARAMS RESULT THROW MAXROWS WINSTART WINSIZE MY PROFILE",
		$opt) || return 1;

	if ( defined $$opt{winstart} ^ defined $$opt{winsize} ) {
		$self->ErrorLang ("SQL", 'sql_winstart_winsize');
		return 1;
	}

	if ( defined $$opt{winstart} && defined $$opt{maxrows} ) {
		$self->ErrorLang ("SQL", 'sql_maxrows');
		return 1;
	}

	if ( defined $$opt{db} && defined $$opt{dbh} ) {
		$self->ErrorLang ("SQL", 'sql_db_dbh_combination');
		return 1;
	}

	my ($db, $driver) = $self->resolve_db ('SQL', $$opt{db});
	return 1 unless $driver;

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
	}
	
	$$opt{throw} ||= "sql";
	
	my $dr = $driver->new(
		db_name => $db,
		apache_mod => $self->{apache_mod},
		dbh_var => $$opt{dbh},
	);

	pop @{$self->{sql_driver_stack}};
	push @{$self->{sql_driver_stack}}, $dr;

	if ( $self->{profile} ) {
		$self->{output}->Write (
			$self->get_profile_start_code
		);

		pop @{$self->{sql_profile_stack}};
		my $profile = $opt->{profile} || substr ($opt->{sql},0,38);
		$profile =~ s/\s+/ /g;
		push @{$self->{sql_profile_stack}}, $profile;
	}

	$self->{output}->Write (
		$dr->Begin_SQL (
			sql => $$opt{sql},
			result => $$opt{result},
			throw => $$opt{throw},
			maxrows => $$opt{maxrows},
			winstart => $$opt{winstart},
			winsize => $$opt{winsize},
			gen_my => $$opt{'my'},
			input_lref => \@input,
			var_lref => \@var
		)
	);

	return $in_print_statement;
}

sub store_used_object {
	my $self = shift;
	
	my ($object_file, $ext) = @_;

	if ( $object_file eq 'default' and $ext eq 'cipp-db' ) {
		$object_file = "__default";
	}

	$object_file =~ s/^[^\.]+\.//;
	$object_file =~ s!\.!/!g;
	$object_file .= ".$ext";

	$self->{direct_used_objects}->{"$object_file:$ext"} = 1;
}

sub resolve_db {
	my $self = shift;
	
	my ($command, $db) = @_;

	# project name does not matter, we delete it
	$db =~ s/^[^\.]+.//;

	if ( $CFG::VERSION ) {
		# with new.spirit 2.x the naming of the default
		# database has changed: it is always called 'default'
		# regardless, which database was given to CIPP
		# as the default database. This way no recompilation
		# of CIPP programs is needed, if the default database
		# has changed.
		$db ||= 'default';
	} else {
		$db ||= $self->{default_db};
	}

	$self->{used_databases}->{$db} = 1;
	$self->store_used_object ($db, "cipp-db");

	if ( $db eq 'default' and not $self->{default_db} ) {
		$self->ErrorLang ($command, 'sql_no_default_db');
		return;
	}

	my $driver = $self->{db_driver}->{$db};
	$driver =~ s/CIPP_/CIPP::/;
	
	if ( $driver eq '' ) {
		$self->ErrorLang ($command, 'sql_unknown_database', [$db]);
		return;
	}

	return ($db, $driver);
}

sub Process_Commit {
	my $self = shift;
	my ($opt, $end_tag) = @_;

	$self->Check_Options ("COMMIT", "", "DB DBH THROW", $opt) || return 1;

	if ( defined $$opt{db} && defined $$opt{dbh} ) {
		$self->ErrorLang ("SQL", 'sql_db_dbh_combination');
		return 1;
	}

	my ($db, $driver) = $self->resolve_db ('COMMIT', $$opt{db});
	return 1 unless $driver;

	my $dr = $driver->new(
		db_name => $db,
		apache_mod => $self->{apache_mod},
		dbh_var => $$opt{dbh},
	);

	$$opt{throw} ||= "commit";

	$self->{output}->Write (
		$dr->Commit(
			throw => $$opt{throw}
		)
	);

	return 1;
}

sub Process_Rollback {
	my $self = shift;
	my ($opt, $end_tag) = @_;

	$self->Check_Options ("ROLLBACK", "", "DB DBH THROW", $opt) || return 1;

	if ( defined $$opt{db} && defined $$opt{dbh} ) {
		$self->ErrorLang ("SQL", 'sql_db_dbh_combination');
		return 1;
	}

	my ($db, $driver) = $self->resolve_db ('ROLLBACK', $$opt{db});
	return 1 unless $driver;

	my $dr = $driver->new(
		db_name => $db,
		apache_mod => $self->{apache_mod},
		dbh_var => $$opt{dbh},
	);

	$$opt{throw} ||= "rollback";

	$self->{output}->Write (
		$dr->Rollback(
			throw => $$opt{throw}
		)
	);

	return 1;
}

sub Process_Autocommit {
	my $self = shift;
	my ($opt, $end_tag) = @_;

	$self->Check_Options ("AUTOCOMMIT", "", "ON OFF DB DBH THROW", $opt)
		 || return 1;

	if ( defined $$opt{db} && defined $$opt{dbh} ) {
		$self->ErrorLang ("SQL", 'sql_db_dbh_combination');
		return 1;
	}

	my ($db, $driver) = $self->resolve_db ('AUTOCOMMIT', $$opt{db});
	return 1 unless $driver;

	if ( !defined $$opt{on} && !defined $$opt{off} ) {
		$self->ErrorLang ("AUTOCOMMIT", 'autocommit_on_off');
		return 1;
	}

	my $status = 1;
	$status = 0 if defined $$opt{off};

	my $dr = $driver->new(
		db_name => $db,
		apache_mod => $self->{apache_mod},
		dbh_var => $$opt{dbh},
	);

	$$opt{throw} ||= "autocommit";

	$self->{output}->Write (
		$dr->Autocommit(
			status => $status,
			throw => $$opt{throw}
		)
	);

	return 1;
}

sub Process_Getdbhandle {
	my $self = shift;
	my ($opt, $end_tag) = @_;

	$self->Check_Options ("GETDBHANDLE", "VAR", "MY DB", $opt)
		 || return 1;

	my ($db, $driver) = $self->resolve_db ('GETDBHANDLE', $$opt{db});
	return 1 unless $driver;

	$$opt{var} = '$'.$$opt{var} if $$opt{var} !~ /^\$/;

	my $dr = $driver->new( db_name => $db, apache_mod => $self->{apache_mod} );

	$self->{output}->Write (
		$dr->Get_DB_Handle(
			var => $$opt{var},
			gen_my => $$opt{'my'}
		)
	);

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
		$self->ErrorLang ("EXECUTE", 'execute_no_apache' );
		return 1;
	}

	$self->ErrorLang ("EXECUTE", 'execute_disabled');
	return 1;

	$self->Check_Options ("EXECUTE", "NAME", "*", $opt);

	my $name = $$opt{name};
	delete $$opt{name};

	if ( (!defined $$opt{var}) && (!defined $$opt{filename}) ) {
		$self->ErrorLang ("EXECUTE", 'execute_missing_var_fn');
		return 1;
	}
	if ( defined $$opt{var} && defined $$opt{filename} ) {
		$self->ErrorLang ("EXECUTE", 'execute_comb_var_fn');
		return 1;
	}

	my $throw = $$opt{throw} || 'EXECUTE';

	# Parameter ¸bergeben

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
		$code .= qq{my $$opt{var};\n} if $$opt{'my'};
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

	$self->Check_Options ("DBQUOTE", "VAR", "DBVAR DBH DB MY", $opt) || return 1;

	if ( defined $$opt{db} && defined $$opt{dbh} ) {
		$self->ErrorLang ("SQL", 'sql_db_dbh_combination');
		return 1;
	}

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

	my ($db, $driver) = $self->resolve_db ('DBQUOTE', $$opt{db});
	return 1 unless $driver;

	my $dh = $driver->new (
		db_name => $db,
		apache_mod => $self->{apache_mod},
		dbh_var => $$opt{dbh},
	);

	$self->{output}->Write (
		$dh->Quote_Var (
			var => $$opt{var},
			db_var => $$opt{dbvar},
			gen_my => $$opt{'my'}
		)
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
	$my = 'my ' if defined $$opt{'my'};
	
	if ( defined $$opt{excvar} ) {
                $$opt{excvar} = "\$".$$opt{excvar} if $$opt{excvar} !~ /^\$/;
		$self->{output}->Write ("$my$$opt{excvar} = \$cipp_exception;\n");
	}

	if ( defined $$opt{msgvar} ) {
                $$opt{msgvar} = "\$".$$opt{msgvar} if $$opt{msgvar} !~ /^\$/;
		$self->{output}->Write ("$my$$opt{msgvar} = \$cipp_exception_msg;\n");
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
		$self->ErrorLang ("MY", 'parameter_missing');
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
			$self->ErrorLang ("MY", 'my_unknown_type', [$var]);
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
	$code .= "my \$cipp_filehandle = CGI::param($formvar);\n";
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

	my $name = $$opt{name};
	my $apache_mod = $self->{apache_mod};
	
	if ( not $$opt{runtime} and not $apache_mod ) {
		$name =~ s/^[^\.]+//;
		$name = $self->{project}.$name;
		if ( ! defined $self->Object_Exists($name) ) {
			$self->ErrorLang ("CONFIG", 'object_not_found', [$name]);
			return 1;
		}
		if ( $self->Get_Object_Type ($name) ne 'cipp-config' ) {
			$self->ErrorLang("CONFIG", 'config_no_config', [$name]);
			return 1;
		}
		$self->{used_configs}->{$name} = 1;
	}

	my $throw = $$opt{throw};
	$throw ||= 'config';

	my $require;

	if ( not $apache_mod ) {
		# Projektname muﬂ raus, sonst Probleme mit mod_perl, wenn Configs
		# aus Subroutines heraus eingebunden werden
		$name =~ s/^[^\.]+\.//;

		$self->{output}->Write (qq{
		CIPP::Runtime::Read_Config("\$cipp::back_prod_path/config/$name.config", "$$opt{nocache}");
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

	my $my_cmd = $$opt{'my'} ? 'my ' : '';
	
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

	my $my_cmd = $$opt{'my'} ? 'my ' : '';

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
	$self->{output}->Write ("my $$opt{var};\n") if $$opt{'my'};

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

	$self->Check_Options ("GETURL", "NAME", "*", $opt)
		 || return 1;

	# mangle URLVAR and VAR options. URLVAR is depreciated.
	
	if ( $opt->{var} ) {
		if ( $opt->{urlvar} ) {
			$self->ErrorLang ("GETURL", 'geturl_mangling', []);
			return 1;
		}
		$opt->{urlvar} = $opt->{var};
		delete $opt->{var};
	}

	my $name = $$opt{name};
	my $runtime = $$opt{runtime};

	my $apache_mod = $self->{apache_mod};

	delete $$opt{runtime} if $runtime;
	my $throw = $$opt{throw};
	delete $$opt{throw} if $throw;
	
	if ( not $runtime and not $apache_mod ) {
		if ( ! defined $self->Object_Exists($name) ) {
			$self->ErrorLang ("GETURL", 'object_not_found', [$name]);
			return 1;
		}
	}

	$$opt{urlvar}='$'.$$opt{urlvar} if $$opt{urlvar} !~ /^\$/;
	my $my_cmd = $$opt{'my'} ? 'my ' : '';

	my $object_url;
	
	if ( not $runtime and not $apache_mod ) {
		$object_url = $self->Get_Object_URL ($name);
		if ( ! defined $object_url ) {
			$self->ErrorLang ("GETURL", 'object_has_no_url', [$name]);
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

	# Zu ¸bergebende Parameter in eine Liste schreiben
	my @val_list;
	my ($par, $val);

	# Zun‰chst mal die Angaben aus PARAMS einlesen

	if ( defined $$opt{params} ) {
		my @parlist = split (/\s*,\s*/, $$opt{params});
		while ( $par = shift @parlist ) {
			$val = $par;
			$par =~ s/^[\$\@]//;
			$val = '$'.$val if $val !~ /^[\$\@]/;
			push @val_list, "$val\t$par";
		}
	}

	# Dann zus‰tzliche benannte Parameter

	while ( ($par,$val) = each %{$opt} ) {
		next if	$par eq 'name' or $par eq 'urlvar' or
			$par eq 'params' or $par eq 'my';
		push @val_list, "$val\t$par";
	}

	# nun stehen in @val_list zwei tab delimited Eintr‰ge von
	# folgender Form
	#	1.	Zugewiesener Parameter
	#		wenn $ am Anfang: scalare Variable
	#		wenn @ am Anfang: Liste
	#		wenn weder $ noch @ am Anfang: konstanter String
	# 	2.	Name des Parameters f¸r die URL
	# nun noch ein paar Syntaxchecks

	if ( not $runtime and not $apache_mod ) {
		my $target_object_type = $self->Get_Object_Type ($name);
		if ( $target_object_type ne 'cipp' && (scalar @val_list) ) {
			$self->ErrorLang ("GETURL", 'geturl_params_cgi_only');
			return 1;
		}
	}

	# URL generieren: wenn Parameter vorhanden: anh‰ngen!

	if ( scalar @val_list ) {
		# Zun‰chst werden scalare Parameter in EINER Stringzuweisung 
		# generiert. Anschlieﬂend werden Arrayparameter dynamisch
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
		$self->ErrorLang ("FORM", 'object_not_found', [$name]);
		return 1;
	}

	if ( not $self->{apache_mod} and $self->Get_Object_Type ($name) ne 'cipp' ) {
		$self->ErrorLang ("FORM", 'form_no_cgi', [$name]);
		return 1;
	}

	my $object_url = $self->Get_Object_URL ($name);

	my $code = qq{print qq[<FORM ACTION="$object_url" }.
		   qq{METHOD=$method};

	# alle restlichen Parameter werden als Optionen in das
	# FORM-Tag geschrieben

	my ($par, $val);
	while ( ($par,$val) = each %{$opt} ) {
		$par =~ tr/a-z/A-Z/;	# schˆner so, sacht der Jˆrn
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
			$self->ErrorLang ("IMG", 'object_not_found', [$name]);
			return 1;
		}
		my $type = $self->Get_Object_Type ($name);
		if ( $type ne 'cipp-img' ) {
			$self->ErrorLang ("IMG", 'img_no_image', [$name]);
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
		$par =~ tr/a-z/A-Z/;	# schˆner so, sacht der Jˆrn
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
		$self->ErrorLang ("A", 'object_not_found', [$name]);
		return 1;
	}

	my $object_url = $self->Get_Object_URL ($name);

	if ( ! defined $object_url ) {
		$self->ErrorLang ("A", 'object_has_no_url', [$name]);
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
		$par =~ tr/a-z/A-Z/;	# schˆner so, sacht der Jˆrn
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
		pop @{$self->{context_stack}};
		$self->Check_Options ("/TEXTAREA", "", "", $opt) || return 1;
		$self->{output}->Write (q[}); print "</TEXTAREA>";]."\n");
		return 1;
	}

	my $options = '';
	my ($par, $val);
	while ( ($par,$val) = each %{$opt} ) {
		$par =~ tr/a-z/A-Z/;	# schˆner so, sacht der Jˆrn
		$options .= qq[ $par="$val"];
	}

	$self->{output}->Write (
		qq[print qq{<TEXTAREA$options>},CIPP::Runtime::HTML_Quote (qq{]
	);

	push @{$self->{context_stack}}, 'var';
	
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
	
	return 1;
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

	# Zu ¸bergebende Parameter in eine Liste schreiben
	my @val_list;
	my ($par, $val);

	# Zun‰chst mal die Angaben aus PARAMS einlesen

	if ( defined $$opt{params} ) {
		my @parlist = split (/\s*,\s*/, $$opt{params});
		while ( $par = shift @parlist ) {
			$val = $par;
			$par =~ s/^[\$\@]//;
			$val = '$'.$val if $val !~ /^[\$\@]/;
			push @val_list, "$val\t$par";
		}
	}

	# Dann zus‰tzliche benannte Parameter

	while ( ($par,$val) = each %{$opt} ) {
		next if $par eq 'params';
		push @val_list, "$val\t$par";
	}

	# nun stehen in @val_list zwei tab delimited Eintr‰ge von
	# folgender Form
	#	1.	Zugewiesener Parameter
	#		wenn $ am Anfang: scalare Variable
	#		wenn @ am Anfang: Liste
	#		wenn weder $ noch @ am Anfang: konstanter String
	# 	2.	Name des Parameters f¸r die URL

	# nun noch ein paar Syntaxchecks

	if ( !(scalar @val_list) ) {
		$self->ErrorLang ("HIDDENFIELDS", 'parameter_missing');
		return 1;
	}

	# Formularfelder generieren

	# Zun‰chst werden scalare Parameter generiert. Anschlieﬂend werden
	# die Felder f¸r Arrayparameter dynamisch erstellt.

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
			# VALUE Options werden gequotet!
			$code .= qq[ VALUE="}.CIPP::Runtime::Field_Quote].
		   		 qq[(qq{$$opt{value}}).qq{"];
		} elsif ( $par eq 'src' and not $self->{apache_mod} ) {
			# Die SRC Option enth‰lt eine Bildreferenz (nur wichtig
			# in non Apache Modi)
			if ( ! defined $self->Object_Exists ($val) ) {
				$self->ErrorLang ("INPUT", 'object_not_found', [$val]);
				return 1;
			}
			my $type = $self->Get_Object_Type ($val);
			if ( $type ne 'cipp-img' ) {
				$self->ErrorLang ("INPUT", 'img_no_image', [$val]);
				return 1;
			}
			my $object_url = $self->Get_Object_URL ($val);
			$code .= qq[ src="$object_url"];
		} else {
			# alle anderen Optionen werden ¸bernommen
			$par =~ tr/A-Z/a-z/;	# schˆner so, sacht der Jˆrn
			if ( $par ne 'sticky' ) {
				$code .= qq[ $par="$val"];
			}
		}
	}

	my $sticky_var = $opt->{sticky};

	if ( $sticky_var ) {
		if ( $opt->{type} =~ /^radio$/i and 
		     $opt->{name} !~ /\$/ and not $opt->{checked} ) {
			# sticky feature for type="radio"
	     		if ( $sticky_var == 1 ) {
				$sticky_var = '$'.$opt->{name};
			}
			$code .= qq[},($sticky_var eq qq{$opt->{value}} ? " checked>\\n":">\\n");\n];
		} elsif ( $opt->{type} =~ /^checkbox$/i and
		          $opt->{name} !~ /\$/ and not $opt->{checked} ) {
			# sticky feature for type="checkbox"
			if ( $sticky_var == 1 ) {
				$sticky_var = '@'.$opt->{name};
			}
			$code .= qq[},(grep /^$opt->{value}\$/,$sticky_var) ? " checked>\\n":">\\n";\n];
		}
	} else {
		$code .= ">};\n";
	}

	$self->{output}->Write($code);

	return 1;
}

sub Process_Select {
#
# INPUT:	1. Options
#		2. Ende-Tag?
#
# OUTPUT:	1. Danach innerhalb eines PRINT-Statements?
#
	my $self = shift;
	my ($opt, $end_tag) = @_;

	if ( $end_tag ) {
		$self->{__inside_select_tag} = undef;
		$self->Check_Options ("/SELECT", "", "", $opt) || return 1;
		$self->{output}->Write(
			qq{print "</SELECT>\\n";}
		);
		return 1;
	}

	if ( $self->{__inside_select_tag} ) {
		$self->ErrorLang ("SELECT", 'select_nesting', []);
		return 1;
	}

	$self->{__inside_select_tag} = $opt;

	$self->Check_Options ("SELECT", "NAME", "*", $opt) || return 1;

	my $code = qq[print qq{<SELECT];
	my ($par, $val);
	while ( ($par,$val) = each %{$opt} ) {
		if ( $par ne 'sticky' ) {
			$code .= qq[ $par="$val"];
		}
	}
	$code .= ">};\n";

	$self->{output}->Write($code);

	return 1;
}

sub Process_Option {
#
# INPUT:	1. Options
#		2. Ende-Tag?
#
# OUTPUT:	1. Danach innerhalb eines PRINT-Statements?
#
	my $self = shift;
	my ($opt, $end_tag) = @_;

	if ( $end_tag ) {
		$self->Check_Options ("/OPTION", "", "", $opt) || return 1;
		pop @{$self->{context_stack}};
		$self->{output}->Write(
			qq[}),"</OPTION>\\n";]
		);
		return 1;
	}

	my $select_options = $self->{__inside_select_tag};
	if ( not $select_options ) {
		$self->ErrorLang ("OPTION", 'select_missing', []);
		return 1;
	}

	$self->Check_Options ("OPTION", "", "*", $opt) || return 1;

	my $code = qq[print qq{<OPTION];

	my ($par, $val);
	while ( ($par,$val) = each %{$opt} ) {
		if ( $par eq 'value' ) {
			$code .= qq[ VALUE="}.CIPP::Runtime::Field_Quote].
		   		 qq[(qq{$$opt{value}}).qq{"];
		} else {
			$par =~ tr/A-Z/a-z/;	# schˆner so, sacht der Jˆrn
			if ( $par ne 'sticky' ) {
				$code .= qq[ $par="$val"];
			}
		}
	}

	my $sticky_var = $select_options->{sticky} || $opt->{sticky};

	if ( $sticky_var ) {
		if ( $opt->{name} !~ /\$/ and not $opt->{selected} and
		     $select_options->{multiple} ) {
			if ( $sticky_var == 1 ) {
				$sticky_var = '@'.$select_options->{name};
			}
			$code .= qq[},(grep /^$opt->{value}\$/,$sticky_var) ? " selected>":">\\n",\n];
		} elsif ( $opt->{name} !~ /\$/ and not $opt->{selected} ) {
			if ( $sticky_var == 1 ) {
				$sticky_var = '$'.$select_options->{name};
			}
			$code .= qq[},($sticky_var eq qq{$opt->{value}}) ? " selected>":">\\n",\n];
		}
	} else {
		$code .= ">},\n";
	}

	$self->{output}->Write($code);
	$self->{output}->Write (
		qq[CIPP::Runtime::HTML_Quote (qq{]
	);

	push @{$self->{context_stack}}, 'var';

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
#			      "Zusammen mit NOINPUT kˆnnen keine Parameter deklariert werden");
#		return 1;
	}

	if ( not defined $$opt{output} ) {
		$self->{inc_nooutput} = 1;
#		$self->Error ("INCINTERFACE",
#			      "Zusammen mit NOOUTPUT kˆnnen keine ".
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
				$self->{inc_bare}->{$var_name} = 1;
			} else {
				push @unknown, $var;
			}
		}
		
	}
		
	if ( @untyped ) {
		$self->ErrorLang (
			"INCINTERFACE",
			'incint_no_types', [join(", ", @untyped)]
		);
		return 1;
	}

	if ( @unknown ) {
		$self->ErrorLang (
			"INCINTERFACE",
			'incint_unknown', [join(", ", @unknown)]
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
		$$opt{'my'} = 1;
	}

	if ( $var !~ /^[\$\@]/ ) {
		$self->ErrorLang (
			"GETPARAM",
			'getparam_no_type', [$var]
		);
		return 1;
	}

	my $my = $$opt{'my'} ? 'my' : '';

	$self->{output}->Write("$my $var = CGI::param(\"$$opt{name}\");\n");

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
		$self->ErrorLang (
			"GETPARAMLIST",
			'getparamlist_no_array', [$var]
		);
		return 1;
	}

	my $my = $$opt{'my'} ? 'my' : '';

	$self->{output}->Write("$my $var = CGI::param();\n");

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

	$self->Check_Options ("!AUTOPRINT", "", "OFF ON", $opt) || return 1;

	if ( $$opt{off} ) {
		$self->{gen_print} = 0;
		$self->{autoprint_off} = 1;
	}
	
	if ( $$opt{on} ) {
		$self->{gen_print} = 1;
	}

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
		qq{undef \@CGI::QUERY_PARAM;\n}.
		qq{my \$cipp_old_no_db_connect = \$CIPP_Exec::no_db_connect;\n}.
		qq{\$CIPP_Exec::no_db_connect = 1;\n}.
		qq{\$cipp_apache_request->internal_redirect ("$url");}.
		qq{\$CIPP_Exec::no_db_connect = \$cipp_old_no_db_connect;\n}
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
	my $my = $$opt{'my'} ? 'my' : '';

	$self->{output}->Write("$my $var = \$cipp_apache_request;\n");

	return 1;
}

sub Process_Dump {
#
# INPUT:	1. Options
#		2. Ende-Tag?
#
# OUTPUT:	1. Danach innerhalb eines PRINT-Statements?
#
	my $self = shift;
	my ($opt, $end_tag) = @_;

	$self->Check_Options ("DUMP", "", "*", $opt) || return 1;

	$self->{output}->Write(
		"use Data::Dumper;\n".
		"print '<pre>".
		join(', ',keys %{$opt}).
		": ', Dumper (".
		join(', ',keys %{$opt}).
		"), '</pre>';\n"
	);

	return 1;
}

sub Process_Exit {
#
# INPUT:	1. Options
#		2. Ende-Tag?
#
# OUTPUT:	1. Danach innerhalb eines PRINT-Statements?
#
	my $self = shift;
	my ($opt, $end_tag) = @_;

	$self->Check_Options ("EXIT", "", "", $opt) || return 1;

	$self->{output}->Write("goto end_of_cipp_program;\n");

	return 1;
}

sub Process_Module {
#
# INPUT:	1. Options
#		2. Ende-Tag?
#
# OUTPUT:	1. Danach innerhalb eines PRINT-Statements?
#
	my $self = shift;
	my ($opt, $end_tag) = @_;

	if ( $end_tag ) {
		$self->Check_Options ("/MODULE", "", "", $opt) || return 1;
		$self->{output}->Write("1;\n");
		return 1;
	}

	$self->Check_Options ("MODULE", "NAME", "", $opt) || return 1;

	if ( $self->{module_name} ) {
		$self->ErrorLang (
			"MODULE",
			'one_module_allowed'
		);
		return 1;
	}
	
	$self->{module_name} = $$opt{name};

	$self->{output}->Write("package $$opt{name};\n");

	return 1;
}

sub Process_Use {
#
# INPUT:	1. Options
#		2. Ende-Tag?
#
# OUTPUT:	1. Danach innerhalb eines PRINT-Statements?
#
	my $self = shift;
	my ($opt, $end_tag) = @_;

	$self->Check_Options ("USE", "NAME", "", $opt) || return 1;

	$self->{output}->Write(
		qq[use $$opt{name};\n]
	);

	return 1;
}

sub Process_Require {
#
# INPUT:	1. Options
#		2. Ende-Tag?
#
# OUTPUT:	1. Danach innerhalb eines PRINT-Statements?
#
	my $self = shift;
	my ($opt, $end_tag) = @_;

	$self->Check_Options ("REQUIRE", "NAME", "ISA", $opt) || return 1;

	my $isa_code;
	if ( $$opt{isa} and $self->{module_name} ) {
		$isa_code = qq[\npush \@$self->{module_name}::ISA, \$cipp_mod;\n];
	}

	$self->{output}->Write(
		qq[{ my \$cipp_mod = "$$opt{name}";\n].
		qq[\$cipp_mod =~ s!::!/!og;\n].
		qq[require \$cipp_mod.".pm"; $isa_code}\n]
	);

	if ( $$opt{name} !~ /\$/ ) {
		$self->{used_modules}->{$$opt{name}} = 1;
	}

	return 1;
}

sub Process_Profile {
#
# INPUT:	1. Options
#		2. Ende-Tag?
#
# OUTPUT:	1. Danach innerhalb eines PRINT-Statements?
#
	my $self = shift;
	my ($opt, $end_tag) = @_;

	$self->Check_Options ("!PROFILE", "", "ON OFF DEEP", $opt) || return 1;

	my $deep = '';
	if ( $opt->{on} ) {
		if ( $opt->{deep} ) {
			$self->{profile} = "deep";
			$deep = " DEEP";
		} else {
			$self->{profile} = "on";
		}
	}
	
	if ( $opt->{off} ) {
		$self->{profile} = undef;
		$self->{output}->Write(
			'printf STDERR "PROFILE %5d STOP'.$deep.'\n",$$;'
		);
	} else {
		$self->{output}->Write(
			'printf STDERR "\nPROFILE %5d START'.$deep.'\n",$$;'
		);
	}

	return 1;
}

sub Process_Httpheader {
#
# INPUT:	1. Options
#		2. Ende-Tag?
#
# OUTPUT:	1. Danach innerhalb eines PRINT-Statements?
#
	my $self = shift;
	my ($opt, $end_tag) = @_;

	if ( $end_tag ) {
		if ( exists $self->{http_header_old_output} ) {
			pop @{$self->{context_stack}};
			$self->{output} = delete $self->{http_header_old_output};
		}
		$self->Check_Options ("/!HTTPHEADER", "", "", $opt) || return 1;
		return 1;
	}

	$self->Check_Options ("!HTTPHEADER", "VAR", "MY", $opt) || return 1;

	if ( $self->{http_header_perl_code} ) {
		$self->ErrorLang (
			"!HTTPHEADER",
			'one_http_header_allowed'
		);
		return 0;
	}

	my $o_handle = new CIPP::OutputHandle (
		\$self->{http_header_perl_code}
	);

	$self->{http_header_old_output} = $self->{output};
	$self->{output} = $o_handle;

	$self->{output}->Write (
		qq[my $opt->{var} = \\\%CIPP_Exec::cipp_http_header;\n]
	);

	push @{$self->{context_stack}}, 'perl';

	return 0;
}

sub Process_Comment {
#
# INPUT:	1. Options
#		2. Ende-Tag?
#
# OUTPUT:	1. Danach innerhalb eines PRINT-Statements?
#
	my $self = shift;
	my ($opt, $end_tag) = @_;

	if ( $end_tag ) {
		pop @{$self->{context_stack}};
		$self->Check_Options ("/#", "", "", $opt) || return 1;
		return 1;
	}

	$self->Check_Options ("#", "", "", $opt) || return 1;

	push @{$self->{context_stack}}, 'comment';

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

#	print STDERR "resolve: $object $object_type\n";

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

#		print STDERR "file='$file'\n";

		if ( defined $object_type ) {
			my $object_ext = $object_type;
			
			if ( $object_type eq 'cipp-img' ) {
				my ($type, $ext) = $self->Get_Object_Type ($object);
				$object_ext = $ext;
			}

			$file .= ".$object_ext";

			my $object_file = $object;
			$object_file =~ s/^[^\.]+\.//;
			$object_file =~ s!\.!/!g;
			$object_file .= ".$object_ext";

			$self->{direct_used_objects}->{"$object_file:$object_type"} = 1
				unless $self->{object_name} eq $object;
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

	my $type = $self->Get_Object_Type ($object);

	if ( defined $type ) {
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

	confess "Get_Object_Type im Apache-Modus aufgerufen" if $self->{apache_mod};

	my $file = $self->Resolve_Object_Source ($object, undef);

#	print STDERR "src='$file'\n";

	my @filenames;

	if ( $Config{osname} =~ /win/i ) {
		# unter spirit/NT klappt das FileGlobbing 'n Scheiﬂ, wenn driver.cgi
		# von nph-make_all aufgerufen wird
		my $dir = dirname $file;
		my $filename = basename $file;
		my $dh = new FileHandle;
		opendir $dh, $dir or 
		    die ("Verzeichnis $dir konnte nicht geoeffnet werden");
		@filenames = grep (!/\.m$/, (grep /^$filename\.[^\.]+$/, readdir $dh));
		closedir $dh;
	} else {
		# new.spirit 2.x .m property Dateien rausfiltern
		@filenames = grep !/\.m$/, <$file.*>;
	}

	return undef if scalar @filenames != 1;
	$filenames[0] =~ /\.([^\.]+)$/;
	my $ext = $1;
	my $type = $ext;
	
	if ( $ext =~ /^(gif|jpg|jpeg|jpe|png)$/i ) {
		$type = 'cipp-img';
	}

	my $object_file = $object;
	$object_file =~ s/^[^\.]+\.//;
	$object_file =~ s!\.!/!g;
	$object_file .= ".$ext";

	$self->Set_Direct_Used_Object ($object_file, $type)
		unless $self->{object_name} eq $object;

	if ( wantarray ) {
		return ($type, $ext);
	} else {
		return $type;
	}
}

sub Set_Direct_Used_Object {
	my $self = shift;

	my ($object_file, $type) = @_;
	
	$self->{direct_used_objects}->{"$object_file:$type"} = 1;
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
# DESCRIPTION:	Es wird die URL des angegebenen Objekts zur¸ckgegeben.
#		Dabei wird - wenn mˆglich - eine relative URL generiert.
#		Derzeit werden relative URL's generiert, wenn aus einer
#		statischen Seite (cipp-html) auf ein statisches Objekt
#		(cipp-html oder cipp-img) verwiesen wird.
#
	my ($self, $object, $absolute_url) = @_;

	# Als Apache-Modul gibt es keine Objektnamen. Hier werden immer
	# direkt URL's verwendet, so daﬂ $object unver‰ndert zur¸ck-
	# gegeben wird
	
	if ( $self->{apache_mod} ) {
		return $object;
	}

	# F¸r normales CIPP geht's hier weiter

	my ($object_type, $object_ext) = $self->Get_Object_Type ($object);
	my $object_path = $object;

	$object_path =~ s!\.!/!g;
	$object_path =~ s![^\/]*!\$CIPP_Exec::cipp_project!;
				# aktuelles Projekt
				# einsetzen
	
	my $object_url;

	if ( $object_type eq 'cipp' ) {
		$object_url = "\$CIPP_Exec::cipp_cgi_url/$object_path.cgi";
	} elsif ( $object_type eq 'cipp-html' ) {
		$object_url =  "\$CIPP_Exec::cipp_doc_url/$object_path.html";
	} elsif ( $object_type eq 'cipp-img' ) {
		my $ext;
		if ( $object_type ne $object_ext ) {
			# newspirit2 - kein .cipp-img mehr, sondern richtige
			# Extensions. Wir brauchen kein Get_Image_Info
			# in diesem Fall
			$ext = $object_ext;
		} else {
			$ext = $self->Get_Image_Info($object);
		}

		if ( ! defined $ext ) {
			$self->ErrorLang (
				"GETURL",
				'object_not_found', [$object]);
			return undef;
		}

		$object_url = "\$CIPP_Exec::cipp_doc_url/$object_path.$ext";
	} else {
		$object_url =  "\$CIPP_Exec::cipp_doc_url/$object_path.$object_ext";
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

	$filename =~ s!^(.*)/([^/]*)$!$1/.$2!;
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

		# Wenn ein " im Parameternamen vorkommt, muﬂ ein Syntaxfehler
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

sub get_profile_start_code {
	my $self = shift;
	
	return	"require 'Time/HiRes.pm';\n".
		'my ($_cipp_t1, $_cipp_t2);'."\n".
		'$_cipp_t1 = Time::HiRes::time();'."\n";
}

sub get_profile_end_code {
	my $self = shift;
	
	my ($what, $detail) = @_;

	$what = "q[$what]";
	$detail = "q[$detail]";
	
	return	'$_cipp_t2 = Time::HiRes::time();'."\n".
		'printf STDERR "PROFILE %5d %-10s %-40s %2.4f\n", '.
		'$$, '.$what.','.$detail.', $_cipp_t2-$_cipp_t1;'."\n";
}


sub Process_Include_Sub {
#
# INPUT:	1. Options
#		2. Ende-Tag?
#
# OUTPUT:	1. Danach innerhalb eines PRINT-Statements?
#
	my $self = shift;
	my ($opt, $end_tag, $in_print_statement) = @_;

	$self->Check_Options ("INCLUDE", "NAME", "*", $opt) || return 1;

	# NAME und MY rausholen

	my $name = $$opt{name};
	delete $$opt{name};
	my $my = $$opt{'my'};
	delete $$opt{'my'};

	# Ausgabeparameter aus $opt aussortieren
	
	my %output;

	foreach my $var ( keys %{$opt} ) {
		if ( $var =~ /^[\$\@\%]/ ) {
			# Ausgabeparameter fangen mit $, @, % an
			my $var_name = $opt->{$var};
			$var_name =~ tr/A-Z/a-z/;
			delete $opt->{$var};
			$output{$var_name} = $var,
		}
	}
	

	# Macro-Abhaengigkeitsliste aktualisieren
	$self->{used_macros}->{$name} = 1;

	# Dateinamen des Macros bestimmen
	my $macro_file = $self->Resolve_Object_Source ($name, 'cipp-inc');

	if ( ! defined $macro_file  ) {
		$self->ErrorLang ("INCLUDE", 'object_not_found', [$name]);
		return 1;
	}

	if ( ! -r $macro_file ) {
		$self->ErrorLang ("INCLUDE", 'include_not_readable', [$name, $macro_file]);
		return 1;
	}

	require CIPP::Include;
	my $inc = new CIPP::Include (
		CIPP     => $self,
		name     => $name,
		filename => $macro_file,
		gen_my   => $my,
		input    => $opt,
		output   => \%output
	);

	$inc->process;

	return $in_print_statement;
}

sub Process_Incinterface_Sub {
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

	if ( not defined $$opt{input} and not defined $$opt{optional} ) {
		$self->{inc_noinput} = 1;
	}

	if ( not defined $$opt{output} ) {
		$self->{inc_nooutput} = 1;
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
				$self->{inc_bare}->{$var_name} = $var;
			} else {
				push @unknown, $var;
			}
		}
	}
		
	if ( @untyped ) {
		$self->ErrorLang (
			"INCINTERFACE",
			'incint_no_types', [join(", ", @untyped)]
		);
		return 1;
	}

	if ( @unknown ) {
		$self->ErrorLang (
			"INCINTERFACE",
			'incint_unknown', [join(", ", @unknown)]
		);
		return 1;
	}

	return 1;
}

1;
__END__

=head1 NAME

CIPP - Powerful preprocessor for embedding Perl and SQL in HTML

=head1 SYNOPSIS

 use CIPP;
 my $CIPP = new CIPP ( @params );
 
 # @params are too complex for a synopsis

 $CIPP->Preprocess;

=head1 DESCRIPTION

CIPP = CgI Perl Preprocessor

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

Use 'perldoc CIPP::Manual' for a language reference. There also
exists a PDF document with some additional chapters about CIPP
language basics and configuration hints. This file can be
downloaded from CPAN as an extra package. This is usefull, because
the format of the documentation is PDF and the file has more
than 500kb. Also not every modification of CIPP leads to modification
of the documentation.

=head1 AUTHOR

Jˆrn Reder, joern@dimedis.de

=head1 COPYRIGHT

Copyright 1997-2001 dimedis GmbH, Cologne, All Rights Reserved

This library is free software; you can redistribute it and/or modify
it under the same terms as Perl itself.

=head1 SEE ALSO

perl(1), Apache::CIPP_Handler(3pm)
