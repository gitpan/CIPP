package CIPP::LangDE;

# $Id: LangDE.pm,v 1.1.1.1 2001/03/17 15:44:26 joern Exp $

$VERSION = "0.01";
$REVISION = q$Revision: 1.1.1.1 $;

use strict;

package CIPP::Lang;

%CIPP::Lang::msg = (
	missing_options		=> "fehlende Optionen: %s",
	illegal_options		=> "illegale Optionsn: %s",
	
	object_not_found	=> "Objekt '%s' existiert nicht",
	object_has_no_url	=> "Object '%s' hat keine URL",

	else_alone		=> "ELSE ohne IF oder ELSIF",
	no_block_command	=> "ist kein Block Kommando",
	wrong_nesting		=> "%s anstelle von %s gefunden",
	close_without_start	=> "wird geschlossen ohne Start-Tag",
	gt_not_found		=> "> Zeichen wurde nicht gefunden",
	tag_par_syntax_error	=> "Syntaxfehler bei den Tag-Parametern",
	double_tag_parameter	=> "doppelte Tag-Parameter",
	close_missing		=> "wird nicht geschlossen",
	parameter_missing	=> "keine Parameter angegeben",
	
	var_default_scalar	=> "DEFAULT kann nur bei skalaren Variablen verwendet werden",
	var_invalid_type	=> "Ungültiger TYPE",

	include_recursive	=> "%s wird rekursiv angewendet. Aufrufpfad: %s",
	include_not_readable	=> "Object '%s' ist nicht lesbar oder existiert nicht. Dateiname: %s",
	include_cipp_init	=> "Interner Fehler bei CIPP Präprozessor Initialisierung",
	include_no_in_par	=> "Es dürfen keine Parameter an %s übergeben werden",
	include_no_out_par	=> "%s hat keine Ausgabeparameter",
	include_missing_in_par	=> "Fehlender Eingabeparameter: %s",
	include_unknown_in_par	=> "Unbekannter Eingabeparameter: %s",
	include_unknown_out_par	=> "Unbekannter Ausgabeparameter: %s",
	include_wrong_out_type	=> "Falscher Ausgabeparametertyp: %s",
	include_out_var_eq_par	=> "Ausgabevariable heißt wie Ausgabeparameter: %s",
	
	sql_nest		=> "Verschachtelung von SQL nicht erlaubt",
	sql_winstart_winsize	=> "WINSTART und WINSIZE müssen immer gemeinsam angegeben werden",
	sql_maxrows		=> "MAXROWS kann nicht in Kombination mit WINSTART und WINSIZE verwendet werden",
	sql_no_default_db	=> "es ist keine Default DB definiert",
	sql_unknown_database	=> "Datenbank '%s' unbekannt",
	sql_db_dbh_combination	=> "Kombination von DB und DBH nicht erlaubt",

	autocommit_on_off	=> "weder ON noch OFF angegeben",
	
	execute_no_apache	=> "Der EXECUTE Befehl wird z.Zt. im Apache-Modus nicht unterstützt",
	execute_disabled	=> "Der EXECUTE Befehl ist in dieser Version nicht implementiert",
	execute_missing_var_fn	=> "VAR oder FILENAME muss angegeben werden",
	execute_comb_var_fn	=> "VAR und FILENAME dürfen nicht zusammen angegeben werden",
	
	my_unknown_type		=> "Variable '%s' hat unbekannten Typ",
	
	config_no_config	=> "Objekt '%s' ist kein Config Objekt",
	
	geturl_params_cgi_only	=> "Es können nur Parameter an ein CGI-Objekt übergeben werden",

	form_no_cgi		=> "Zielobjekt ist kein CGI Objekt",
	
	img_no_image		=> "Objekt ist kein Bild",
	
	incint_no_types		=> "Folgende Parameter sind nicht typisiert: %s",
	incint_unknown		=> "Folgende Parameter sind unbekannt: %s",
	
	getparam_no_type	=> "Der Parameter '%s' ist nicht mit \$ oder \@ typisiert!",
	
	getparamlist_no_array	=> "Die Variable '%s' muß eine Arrayvariable sein",
	
	perl_runtime		=> "Perl Fehler: %s",
	
	one_module_allowed	=> "<?MODULE> darf nur einmal verwendet werden",
	module_missing		=> "Der <?MODULE> Befehl fehlt!",
	
	select_nesting		=> "Verschachtelung von <?SELECT> nicht erlaubt",
	select_missing		=> "<?OPTION> darf nicht ohne <?SELECT> verwendet werden",
	
	geturl_mangling		=> "Die Optionen URLVAR und VAR dürfen nicht gleichzeitig verwendet werden",
	
	one_http_header_allowed	=> "<?!HTTPHEADER> darf nur einmal verwendet werden",
);
