package CIPP_Exec;
$cipp::back_prod_path="../..";
BEGIN{$cipp::back_prod_path="../..";}
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
@CIPP_Exec::cipp_dbh_list = ();

$cipp_db_zyn::data_source = $cipp_apache_request->dir_config ("db_zyn_data_source");
$cipp_db_zyn::user = $cipp_apache_request->dir_config ("db_zyn_user");
$cipp_db_zyn::password = $cipp_apache_request->dir_config ("db_zyn_password");
$cipp_db_zyn::autocommit = $cipp_apache_request->dir_config ("db_zyn_auto_commit");
use DBI;
if ( not $CIPP_Exec::no_db_connect ) { eval { $cipp_db_zyn::dbh->disconnect };
$cipp_db_zyn::dbh = DBI->connect (
$cipp_db_zyn::data_source,
$cipp_db_zyn::user,
$cipp_db_zyn::password,
{ PrintError => 0,
  AutoCommit => $cipp_db_zyn::autocommit } );
die "sql_open	$DBI::errstr" if $DBI::errstr;
}
;die "sql_open	dbh is undef" if not $cipp_db_zyn::dbh;
push @CIPP_Exec::cipp_dbh_list, $cipp_db_zyn::dbh;
if ( $cipp_db_zyn::init ) {
my $cipp_sql_code = qq{$cipp_db_zyn::init};
$cipp_db_zyn::dbh->do( $cipp_sql_code );
die "database_initialization	$DBI::errstr
$cipp_sql_code" if defined $DBI::errstr;
}




# cippline 1 "input.cipp"
print qq[<HTML>
<HEAD><TITLE>CIPP-Apache-Test</TITLE></HEAD>
<BODY>
this is a simple test
];


# cippline 5 "input.cipp:&lt;?SQL>"
my $cipp_sql_code = qq{select num from foo};
my $cipp_db_zyn_sth = $cipp_db_zyn::dbh->prepare ( $cipp_sql_code );
die "sql	$DBI::errstr
$cipp_sql_code" if $DBI::errstr;
$cipp_db_zyn_sth->execute();
die "sql	$DBI::errstr
$cipp_sql_code" if defined $DBI::errstr;
my ($num);
my $cipp_col_cnt = $cipp_db_zyn_sth->{NUM_OF_FIELDS};
my @cipp_col_refs = \($num);
while ( @cipp_col_refs < $cipp_col_cnt ) {
  my $dummy;
  push @cipp_col_refs, \$dummy;
}  ;
if ( @cipp_col_refs > $cipp_col_cnt ) {
  splice (@cipp_col_refs, $cipp_col_cnt);
}
$cipp_db_zyn_sth->bind_columns (undef, @cipp_col_refs);
die "sql	$DBI::errstr
$cipp_sql_code" if $DBI::errstr;
my $cipp_db_zyn_maxrows;
SQL: while (  $cipp_db_zyn_sth->fetch ) {




# cippline 7 "input.cipp"
print qq[
  num=$num
];
}
$cipp_db_zyn_sth->finish;
die "SQL	$DBI::errstr" if $DBI::errstr;




# cippline 9 "input.cipp"
print qq[
</BODY>
</HTML>
];
if ( not $CIPP_Exec::no_db_connect ) {
eval { my $cipp_close_dbh;
while ( $cipp_close_dbh = shift @CIPP_Exec::cipp_dbh_list) {
  if ( not $cipp_close_dbh->{AutoCommit} ) {
    $cipp_close_dbh->rollback;
  }
  $cipp_close_dbh->disconnect();
}
};
}
$CIPP_Exec::cipp_http_header_printed = 0;
}; # CIPP-GENERAL-EXCEPTION-EVAL;
end_of_cipp_program:
my $cipp_general_exception = $@;
die $cipp_general_exception if $cipp_general_exception;
