package CIPP_Exec;
my $cipp_back_prod_path;
BEGIN{$cipp_back_prod_path="../..";}
use strict;
$CIPP_Exec::apache_mod = 1;
$CIPP_Exec::apache_program = "input.cipp";
$CIPP_Exec::apache_request = $cipp_apache_request;

my $cipp_query;
if ( ! defined $CIPP_Exec::_cipp_in_execute ) {
	use CIPP::Runtime;
	use CGI;
	package CIPP_Exec;
	$cipp_query = new CGI;
	$cipp_query->import_names('CIPP_Exec');
}

eval { # CIPP-GENERAL-EXCEPTION-EVAL
package CIPP_Exec;
print "Content-type: text/html\nPragma: no-cache\n\n" if not $CIPP_Exec::_cipp_no_http;
$CIPP_Exec::cipp_http_header_printed = 1;

$cipp_db_zyn::data_source = $cipp_apache_request->dir_config ("db_zyn_data_source");
$cipp_db_zyn::user = $cipp_apache_request->dir_config ("db_zyn_user");
$cipp_db_zyn::password = $cipp_apache_request->dir_config ("db_zyn_password");
$cipp_db_zyn::Auto_Commit = $cipp_apache_request->dir_config ("db_zyn_auto_commit");

	use DBI;
	;
	$cipp_db_zyn::dbh = DBI->connect (
	$cipp_db_zyn::data_source,
	$cipp_db_zyn::user,
	$cipp_db_zyn::password,
	{ PrintError => 0 } );
	die "sql_open	$DBI::errstr" if $DBI::errstr;

$cipp_db_zyn::dbh->{AutoCommit} = $cipp_db_zyn::Auto_Commit;
my ($cipp_db_zyn_sth, $cipp_db_zyn_ar, $cipp_db_zyn_maxrows, $cipp_db_zyn_winstart);
# cippline 1 "input.cipp"
print qq[<HTML>
<HEAD><TITLE>CIPP-Apache-Test</TITLE></HEAD>
<BODY>
this is a simple test
];
# cippline 5 "input.cipp:&lt;?SQL>"
my ($num);
my $cipp_sql_code = qq{select num from foo}; $cipp_db_zyn_sth = $cipp_db_zyn::dbh->prepare ( $cipp_sql_code );
die "sql	$DBI::errstr
$cipp_sql_code" if $DBI::errstr;
$cipp_db_zyn_sth->execute();
die "sql	$DBI::errstr
$cipp_sql_code" if defined $DBI::errstr;
SQL: while (  $cipp_db_zyn_ar = $cipp_db_zyn_sth->fetchrow_arrayref ) {
($num) = @{$cipp_db_zyn_ar};
# cippline 7 "input.cipp"
print qq[
  num=$num
];
}
$cipp_db_zyn_sth->finish;
# cippline 9 "input.cipp"
print qq[
</BODY>
</HTML>
];
$CIPP_Exec::cipp_http_header_printed = 0;
}; # CIPP-GENERAL-EXCEPTION-EVAL;
end_of_cipp_program:
my $cipp_general_exception = $@;
eval{
if ( $cipp_db_zyn::dbh and not $cipp_db_zyn::dbh->{AutoCommit} ) {
	$cipp_db_zyn::dbh->rollback;
}
$cipp_db_zyn::dbh->disconnect() if $cipp_db_zyn::dbh;
$cipp_db_zyn::dbh=undef;

};
die $cipp_general_exception if $cipp_general_exception;
