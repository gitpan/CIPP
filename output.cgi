package CIPP_Exec;
use strict;
$CIPP_Exec::apache_mod = 1;
$CIPP_Exec::apache_program = "input.cipp";
$CIPP_Exec::apache_request = $cipp_apache_request;

my $cipp_query;
if ( ! defined $CIPP_Exec::_cipp_in_execute ) {
	use CIPP::Runtime 0.36;
	use CGI;
	package CIPP_Exec;
	$cipp_query = new CGI;
	
}

eval { # CIPP-GENERAL-EXCEPTION-EVAL
package CIPP_Exec;
# Debugging
# CIPP::Runtime::init_request();
CIPP::Runtime::Close_Database_Connections();
$cipp_db_zyn::dbh = undef if not $CIPP_Exec::no_db_connect;




# cippline 1 "input.cipp"
print qq[<HTML>
<HEAD><TITLE>CIPP-Apache-Test</TITLE></HEAD>
<BODY>
this is a simple test
];


# cippline 5 "input.cipp:&lt;?SQL>"
$cipp_db_zyn::dbh ||= CIPP::Runtime::Open_Database_Connection ("zyn", $cipp_apache_request);
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
$CIPP_Exec::cipp_http_header_printed = 0;
}; # CIPP-GENERAL-EXCEPTION-EVAL;
end_of_cipp_program:
my $cipp_general_exception = $@;
CIPP::Runtime::Close_Database_Connections();
die $cipp_general_exception if $cipp_general_exception;
