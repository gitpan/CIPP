package CIPP::DB_DBI;

$VERSION = "0.64";
$REVISION = q$Revision: 1.17 $;

use strict;

#---------------------------------------------------------------------
# $db = new CIPP::DB_DBI (
#	db_name	=> internal name of the database / configuration
#		   (dotted notation is permitted),
#	apache_mod => Apache Request Object, if under Apache::CIPP 
# );
#---------------------------------------------------------------------

sub new {
	my ($type) = shift;

	my %par = @_;
	
	my $db_name    = $par{db_name};
	my $apache_mod = $par{apache_mod};
	my $dbh_var    = $par{dbh_var};

	# name prefix for lexical variables
	my $lex;
	
	# Projektanteil rausnehmen, sonst Probleme mit mod_perl
	$lex =~ s/^[^\.]+\.//;

	($lex = $db_name) =~ tr/./_/;
	$lex = "cipp_db_$lex";

	# name prefix for global variables
	my $pkg;
	if ( $CFG::VERSION ) {
		# since new.spirit 2.x the naming schema for the
		# global database variable has changed, to be
		# more Perl compliant (no lower cased package
		# names, including a _ prevents from name clashing
		# with CPAN package names).
		$pkg = "CIPP_Exec::$lex";
	} else {
		$pkg = $lex;
	}
	my $self = {
			"db_name" => $db_name,
			"lex" => "\$$lex",
			"pkg" => "\$$pkg",
			"type" => undef,		# single | select,
			"apache_mod" => $apache_mod,
			"dbh_var" => $dbh_var,
	};

	return bless $self, $type;
}


#---------------------------------------------------------------------
# $db = $db->Init
#	Initializes Database usage (resets dbh global variable, 
#	database connections are now made on the fly through
#	CIPP::Runtime::Open_Database_Connection)
#---------------------------------------------------------------------

sub Init {
	my $self = shift;
	
	my $pkg = $self->{pkg};
	
	return "$pkg:\:dbh = undef if not \$CIPP_Exec::no_db_connect;\n";
}

#---------------------------------------------------------------------
# $code = $db->Begin_SQL (
#	sql 		=> SQL Code,
#	result		=> Variable for result code,
#	throw		=> Exception to throw on error,
#	maxrows 	=> max. number of rows to select,
#	winstart 	=> number of rows to skip
#	winsize		=> number of rows to fetch after skipping
#	gen_my		=> declaring all variables with my
#	input_lref	=> list reference of input parameters,
#	var_lref	=> list of result variable names
# );
#---------------------------------------------------------------------

sub Begin_SQL {
	my $self = shift;
	
	my %par = @_;
	
	my ($sql, $result, $throw, $maxrows,
	    $winstart, $winsize, $gen_my,
	    $input_lref, $var_lref)
	    =
	   ($par{sql}, $par{result}, $par{throw}, $par{maxrows},
	    $par{winstart}, $par{winsize}, $par{gen_my},
	    $par{input_lref}, $par{var_lref});
	    
	my $db_name	= $self->{db_name};
	my $pkg		= $self->{pkg};
	my $lex		= $self->{lex};

	# Wenn Befehl mit ; abgeschlossen ist, ; entfernen
	$sql =~ s/;$//;

	my ($code, $var, $maxrows_cond, $winstart_cmd);
	
	my $dbh;
	if ( $self->{dbh_var} ) {
		$dbh = $self->{dbh_var};
		$code = "";
	} else {
		$dbh = "${pkg}::dbh";
		$code = $self->Open_Connection_Code ($db_name);
	}

	$maxrows_cond = '';
	$winstart_cmd = '';
	
	my $bind_list = '';
	if ( defined $input_lref and scalar (@{$input_lref}) ) {
		$bind_list = join (",", @{$input_lref});
	}

	if ( defined $var_lref->[0] ) {
		# Aha, wir haben wir ein SELECT Statement oder zumindest etwas,
		# was offensichtlich Rows zurueckliefert (sonst waeren wohl
		# kaum Variablen-Namen uebergeben worden :)

		$self->{type} = "select";

		$var = "\$".join (", \$", @{$var_lref});
		my $var_cnt = scalar @{$var_lref};

		$code .= qq {my \$cipp_sql_code = qq{$sql};\nmy ${lex}_sth = }.
			 qq {${dbh}->prepare ( \$cipp_sql_code );}."\n".
			 qq {die "$throw\t\$DBI::errstr\n\$cipp_sql_code" if \$DBI::errstr;}. "\n";

		$code .= qq {${lex}_sth->execute($bind_list);}."\n".
			 qq {die "$throw\t\$DBI::errstr\n\$cipp_sql_code" if defined \$DBI::errstr;}."\n";

		$code .= qq {my ($var);\n} if $gen_my;
		
		$code .= qq [my \$cipp_col_cnt = ${lex}_sth->{NUM_OF_FIELDS};\n].
			 qq [my \@cipp_col_refs = \\($var);\n].
			 qq [while ( \@cipp_col_refs < \$cipp_col_cnt ) {\n].
			 qq [  my \$dummy;\n].
			 qq [  push \@cipp_col_refs, \\\$dummy;\n].
			 qq [}  ;\n].
			 qq [if ( \@cipp_col_refs > \$cipp_col_cnt ) {\n].
			 qq [  splice (\@cipp_col_refs, \$cipp_col_cnt);\n].
			 qq [}\n];
		
		# the first undef parameter in bind_colums is
		# needed for older DBI versions
		$code .= qq {${lex}_sth->bind_columns (undef, \@cipp_col_refs);\n}.
			 qq {die "$throw\t\$DBI::errstr\n\$cipp_sql_code" if \$DBI::errstr;}. "\n";

		$code .= qq {my ${lex}_maxrows;\n};

		if ( defined $maxrows ) {
			$code .= qq {${lex}_maxrows=$maxrows;\n};
			$maxrows_cond = "${lex}_maxrows-- > 0 and";
		}

		if ( defined $winstart ) {
			$code .= qq {${lex}_maxrows=$winstart+$winsize;\n};
			$code .= qq {my ${lex}_winstart=$winstart;\n};
			$maxrows_cond = "--${lex}_maxrows > 0 and";
			$winstart_cmd =
				qq {next if --${lex}_winstart }.
				qq {> 0;\n};
		}

		$code .= qq [SQL: while ( $maxrows_cond ${lex}_sth->fetch ) {]."\n";

		$code .= $winstart_cmd;

	} else {

		# Anscheinend handelt es sich um ein SINGLE Statment, dass
		# ausser einem einzelnen Wert nichts zurueckliefert wird

		if ( $bind_list ne '' ) {
			$bind_list = ", undef, $bind_list";
		}

		$self->{type} = "single";
		$code .= "my \$cipp_sql_code = qq{$sql};\n";
		if ( defined $result ) {
			$result = "\$".$result if $result !~ /^\$/;
			$code .= 'my ' if $gen_my;
			$code .= qq{$result = };
		}
		$code .= qq{${dbh}->do( \$cipp_sql_code $bind_list);}."\n";
		$code .= qq{die "$throw\t\$DBI::errstr\n\$cipp_sql_code" if defined \$DBI::errstr;}."\n";
	}

	return $code;
}


#---------------------------------------------------------------------
# $code = $db->End_SQL
#---------------------------------------------------------------------

sub End_SQL {
	my $self = shift;
	
	my $db_name	= $self->{db_name};
	my $lex		= $self->{lex};

	if ( $self->{type} eq "select" ) {
		return qq[}\n${lex}_sth->finish;\n].
		       qq[die "SQL\t\$DBI::errstr" if \$DBI::errstr;\n];
	} else {
		return "";
	}
}


#---------------------------------------------------------------------
# $code = $db->Quote_Var (
#	var	=> variable name to quote,
#	db_var	=> variable name for the quoted result,
#	gen_my	=> declare db_var with my
# );
#---------------------------------------------------------------------

sub Quote_Var {
	my $self = shift;

	my %par = @_;

	my ($var, $db_var, $gen_my) =
	   ($par{var}, $par{db_var}, $par{gen_my});

	my $db_name	= $self->{db_name};
	my $pkg		= $self->{pkg};

	my $dbh;
	my $code;
	if ( $self->{dbh_var} ) {
		$dbh = $self->{dbh_var};
		$code = "";
	} else {
		$dbh = "${pkg}::dbh";
		$code = $self->Open_Connection_Code ($db_name);
	}

	$code .= qq{my $db_var;\n} if $gen_my;
	
	$code .= qq{$var = undef if $var eq '';}."\n";
	$code .= qq{$db_var = ${dbh}->quote($var);}."\n";

	return $code;
}


#---------------------------------------------------------------------
# $code = $db->Commit (
#	throw	=> Exception to throw on error,
# );
#---------------------------------------------------------------------

sub Commit {
	my $self = shift;

	my %par = @_;

	my $throw = $par{throw};
	
	my $db_name	= $self->{db_name};
	my $pkg		= $self->{pkg};

#	my $code  = qq{${pkg}::dbh->commit();}."\n";
#	$code .= qq{die "$throw\t\$DBI::errstr" if defined \$DBI::errstr;}."\n";

	my $dbh;
	my $code;
	if ( $self->{dbh_var} ) {
		$dbh = $self->{dbh_var};
		$code = "";
	} else {
		$dbh = "${pkg}::dbh";
		$code = $self->Open_Connection_Code ($db_name);
	}

	$code .= qq[if ( ${pkg}::data_source !~ /mysql/ ) {\n];
	$code .= qq{${dbh}->commit();}."\n";
	$code .= qq{die "$throw\t\$DBI::errstr" if defined \$DBI::errstr;}."\n";
	$code .= qq[}\n];

	return $code;
}


#---------------------------------------------------------------------
# $code = $db->Rollback (
#	throw	=> Exception to throw on error,
# );
#---------------------------------------------------------------------

sub Rollback {
	my $self = shift;

	my %par = @_;

	my $throw = $par{throw};
	
	my $db_name	= $self->{db_name};
	my $pkg		= $self->{pkg};

	my $dbh;
	my $code;
	if ( $self->{dbh_var} ) {
		$dbh = $self->{dbh_var};
		$code = "";
	} else {
		$dbh = "${pkg}::dbh";
		$code = $self->Open_Connection_Code ($db_name);
	}

	$code .= qq{${dbh}->rollback();}."\n";
	$code .= qq{die "$throw\t\$DBI::errstr" if defined \$DBI::errstr;}."\n";

	return $code;
}


#---------------------------------------------------------------------
# $code = $db->AutoCommit (
#	status	=> 1 | 0,
#	throw	=> Exception to throw on error,
# );
#---------------------------------------------------------------------

sub Autocommit {
	my $self = shift;

	my %par = @_;

	my $status = $par{status};
	my $throw  = $par{throw};

	my $db_name	= $self->{db_name};
	my $pkg		= $self->{pkg};

	my $dbh;
	my $code;
	if ( $self->{dbh_var} ) {
		$dbh = $self->{dbh_var};
		$code = "";
	} else {
		$dbh = "${pkg}::dbh";
		$code = $self->Open_Connection_Code ($db_name);
	}

	$code .= qq[if ( ${pkg}::data_source !~ /mysql/ ) {\n];

	if ( $status == 0 ) {
		$code .= qq{${dbh}->{AutoCommit}=0;}."\n";
	} else {
		$code .= qq{${dbh}->{AutoCommit}=1;}."\n";
	}

	$code .= qq[}\n];

	return $code;
}


#---------------------------------------------------------------------
# $code = $db->Get_DB_Handle (
#	var	=> name of the result variable,
#	gen_my	=> declare variable with my
# );
#---------------------------------------------------------------------

sub Get_DB_Handle {
	my $self = shift;

	my %par = @_;

	my $var	   = $par{var};
	my $gen_my = $par{gen_my};

	my $db_name	= $self->{db_name};
	my $pkg		= $self->{pkg};

	$var = "my $var" if $gen_my;

	my $dbh = "${pkg}::dbh";

	my $code;
	$code  = $self->Open_Connection_Code ($db_name);
	$code .= qq{$var = ${dbh};}."\n";

	return $code;
}

sub Open_Connection_Code {
	my $self = shift;
	
	my ($db_name) = @_;

	my $pkg	= $self->{pkg};

	if ( $self->{apache_mod} ) {
		return 	qq[${pkg}::dbh ||= CIPP::Runtime::Open_Database_Connection ("$db_name", \$cipp_apache_request);\n];
	} else {
		return 	qq[${pkg}::dbh ||= CIPP::Runtime::Open_Database_Connection ("$db_name");\n];
	}
}

1;
