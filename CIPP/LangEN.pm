package CIPP::LangEN;

# $Id: LangEN.pm,v 1.6 2001/01/31 11:32:42 joern Exp $

$VERSION = "0.01";
$REVISION = q$Revision: 1.6 $;

use strict;

package CIPP::Lang;

%CIPP::Lang::msg = (
	missing_options		=> "missing parameters: %s",
	illegal_options		=> "illegal parameters: %s",
	
	object_not_found	=> "Object '%s' not found",
	object_has_no_url	=> "Object '%s' has no URL",

	else_alone		=> "ELSE without IF or ELSIF",
	no_block_command	=> "is not a block command",
	wrong_nesting		=> "%s instead of %s found",
	close_without_start	=> "is closed without a starting tag",
	gt_not_found		=> "> character not found",
	tag_par_syntax_error	=> "tag parameter syntax error",
	double_tag_parameter	=> "double tag parameters",
	close_missing		=> "is not closed",
	parameter_missing	=> "parameters are missing",
	
	var_default_scalar	=> "DEFAULT is invalid for non scalar variables",
	var_invalid_type	=> "invalid TYPE",

	include_recursive	=> "recursive usage of %s. caller stack: %s",
	include_not_readable	=> "object '%s' is not readable or does not exist. filename: %s",
	include_cipp_init	=> "internal CIPP preprocessor initialization error",
	include_no_in_par	=> "%s takes no input parameters",
	include_no_out_par	=> "%s defines no output parameters",
	include_missing_in_par	=> "missing input parameters: %s",
	include_unknown_in_par	=> "unknown input parameters: %s",
	include_unknown_out_par	=> "unknown output parameters: %s",
	include_wrong_out_type	=> "wrong output parameter type: %s",
	include_out_var_eq_par	=> "output variable and output parameter have the same name: %s",
	
	sql_nest		=> "nesting of SQL commands is forbidden",
	sql_winstart_winsize	=> "you always must combine WINSTART with WINSIZE",
	sql_maxrows		=> "you cannot combine MAXROWS with WINSTART and WINSIZE",
	sql_no_default_db	=> "no default database is defined",
	sql_unknown_database	=> "unknown database identifier '%s'",
	
	autocommit_on_off	=> "neither ON nor OFF specified",
	
	execute_no_apache	=> "the EXECUTE command is not supported in Apache mode",
	execute_disabled	=> "the EXECUTE command is not implemented in this version of CIPP",
	execute_missing_var_fn	=> "you must specify VAR or FILENAME",
	execute_comb_var_fn	=> "you must not combine VAR and FILENAME",
	
	my_unknown_type		=> "unknown type of variable '%s'",
	
	config_no_config	=> "object '%s' is no Config object",
	
	geturl_params_cgi_only	=> "you can pass parameters to CGI objects only",

	form_no_cgi		=> "ACTION object is not a CGI object",
	
	img_no_image		=> "object is no image",
	
	incint_no_types		=> "missing types of the following parameters: %s",
	incint_unknown		=> "unknown parameters: %s",
	
	getparam_no_type	=> "parameter '%s' is not a scalar or array",
	
	getparamlist_no_array	=> "varaiable '%s' is no array",

	perl_runtime		=> "perl error: %s",
	
	one_module_allowed	=> "multiple usage of <?MODULE> forbidden",
	module_missing		=> "The <?MODULE> command is missing!",
	
	select_nesting		=> "nesting of <?SELECT> forbidden",
	select_missing		=> "usage of <?OPTION> without <?SELECT> forbidden",
	
	geturl_mangling		=> "mixing of URLVAR and VAR options is forbidden",

	one_http_header_allowed	=> "multiple usage of <?!HTTPHEADER> forbidden",
);
