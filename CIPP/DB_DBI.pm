#==============================================================================
#
# MODUL
#       CIPP::DB_DBI
#
# REVISION
#	$Revision: 1.6 $
#
# METHODEN
#       siehe CIPP_DB.interface
#
#
#==============================================================================
# COPYRIGHT
#       (c) 1997-1998 dimedis GmbH, All Rights Reserved
#       programming by Joern Reder
#
#------------------------------------------------------------------------------
#
# MODIFICATION HISTORY
#	06.05.1998 0.1.0.0 joern
#		+ Übernahme von CIPP_DB_MySQL.pm
#		+ Anpassungen im Connect-Code vorgenommen
#
#	14.05.1998 0.2.0.0 joern
#		+ Datenbankhandle wird in eigener Package gehalten, so
#		  daß Aufrufe via <?EXECUTE> dieselbe Datenbankconnection
#		  des umgebenden Scripts verwenden können
#
#	25.06.1998 0.3.0.0 joern
#		+ MY Option bei Begin_SQL eingebaut
#		+ MY Option bei Quote eingebaut
#
#	29.06.1998 0.3.1.0 joern
#		+ der generierte Datenbankcode muß reintrant sein
#		+ es wird nur connected, wenn noch keine Connection existiert
#		+ AutoCommit wird nicht beim Connect gesetzt, da dieser
#		  nur beim ersten Aufruf durchgeführt wird
#		+ Variable für Statement-Handle und Array-Fetch plus diverse
#		  andere pro-SQL-Var. werden nur einmal beim Connecten
#		  mit my deklariert, nicht bei jedem Statement (gibt Fehler
#		  wegen wiederholtem my im selben Scope)
#
#	01.07.1998 0.3.1.1 joern
#		+ Änderungen für die Persistenz von Datenbankconnections
#		+ neuer Parameter beim Konstruktor: persistent
#		+ wenn $persistent true, dann wird kein disconnect()
#		  generiert
#		+ DB-Handle wird in globalem Hash gehalten, damit (im Falle
#		  des OAS) über perlshut.pl die Datenbankconnections wieder
#		  geschlossen werden können
#
#	17.08.1998 0.3.2.0 joern
#		+ Methode für <?GETDBHANDLE> hinzugefügt
#
#	15.09.1998 0.3.3.0 joern
#		+ Bugfix: <?SQL WINSIZE WINSTART>, hier konnten nur Konstanten
#		  und keine Ausdrücke/Variablen übergeben werden
#
#	29.09.1998 0.4.0.0 joern
#		+ Neuer Parameter input_lref bei <?SQL>, ermöglich Parameter
#		  Binding
#
#	25.10.1998 0.4.0.1 joern
#		+ Open hat Parameter no_config_require, der verhindert,
#		  das die DB-Config required wird
#
#	21.11.1998 0.4.0.2 joern
#		+ seltsamen code zum Retten des DB-Handles in eigenem Hash bei
#		  persistenter Umgebung auskommentiert. Das Caching des Handles
#		  erfolgt schließlich über eine Package Variable.
#		+ Wenn bereits ein DB-Handle da ist, wird anhand $dbh->ping
#		  überprüft, ob die Verbindung noch da ist und ggf. eine neue
#		  Verbindung zur Datenbank aufgebaut.
#
#	16.01.1999 0.5.0.0 joern
#		+ Modul umbenannt von CIPP_DB_DBI nach CIPP::DB_DBI
#
#	17.03.1999 0.51 joern
#		+ zunächst wird kein persistenter Datenbankcode erzeugt,
#		  auch wenn dies beim Konstruktor angegeben wird.
#
#	20.06.1999 0.52 joern
#		+ back_prod_path wird dynamisch anhand der Variablen
#		  $cipp_back_prod_path eingesetzt
#
#------------------------------------------------------------------------------

package CIPP::DB_DBI;

$VERSION = "0.51";
$REVISION = q$Revision: 1.6 $;

sub new {
	my ($type) = shift;
	my ($db_name, $persistent) = @_;

	my $pkg;	
	($pkg = $db_name) =~ tr/./_/;
	my $self = {
			# Attribute, die jeder CIPP-DB-Driver hat
			"db_name" => $db_name,
			"pkg" => "\$cipp_db_$pkg",
			"persistent" => $persistent,
			"type" => undef,		# single | select,

			# zusätzliche Attribute für den DBI Driver
			"dbi_version" => '0.93'
	};

	return bless $self, $type;
}


sub Open {
	my $self = shift;
	
	my %arg = @_;
	my $db_name = $self->{db_name};
	my $pkg = $self->{pkg};
	my $back_prod_path = $self->{back_prod_path};

	my $pkg_name = $pkg;
	$pkg_name =~ s/\$//;

#	my $save_handle = '';
#	if ( $self->{persistent} ) {
#		$save_handle = q[$CIPP_Exec::cipp_db_handle{].$pkg_name.q[}=].
#			      qq[${pkg}::dbh;\n]
#	}

	my $require;
	
	if ( $arg{no_config_require} ) {
		$require = "";
#		$require = "\$CIPP_Exec::apache_request->warn('connecting database')";

	} else {
		$require = qq{require "\$cipp_back_prod_path/config/${db_name}.db-conf"};
	}
	
	my $code;
	if ( $self->{dbi_version} ne '0.73' ) {
		$code = qq
#[
#if ( not defined ${pkg}::dbh or not ${pkg}::dbh->ping ) {
[
	use DBI;
	$require;
	${pkg}::dbh = DBI->connect (
	${pkg}::data_source,
	${pkg}::user,
	${pkg}::password,
	{ PrintError => 0 } );
	die "sql_open\t\$DBI::errstr" if \$DBI::errstr;
]
#}
#]
	} else {
		$code = qq
#[
#if ( not defined ${pkg}::dbh ) {
[
	use DBI;
	$require;
	my \$source = ${pkg}::data_source;
	\$source =~ /^dbi:([^:]+)/;
	\$source = \$1;
	${pkg}::drh = DBI->install_driver(\$source);
	die "sqlopen\tFehler bei DBI->install_driver" if \$DBI::errstr;
	${pkg}::dbh = ${pkg}::drh->connect (
	${pkg}::name,
	${pkg}::user,
	${pkg}::password
	);
	die "sql_open\t\$DBI::errstr" if \$DBI::errstr;
]
#}
#]
	}

	$code .= qq
[
${pkg}::dbh->{AutoCommit} = ${pkg}::Auto_Commit;
my (${pkg}_sth, ${pkg}_ar, ${pkg}_maxrows, ${pkg}_winstart);
];
	return $code;
}


sub Close {
	my $self = shift;
	my $db_name = $self->{db_name};
	my $pkg = $self->{pkg};

	my $code = qq[eval{\n].
		   qq[if ( ${pkg}::dbh and not ${pkg}::dbh->{AutoCommit} ) {\n].
		   qq[\t${pkg}::dbh->rollback;\n}\n];

	if ( not $self->{persistent} ) {
		$code .= "${pkg}::dbh->disconnect() if ${pkg}::dbh;\n${pkg}::dbh=undef;\n";
	} else {
		$code .= "# persistence: no dbh->disconnect\n";
	}
	
	$code .= "\n};\n";

	return $code;
}


sub Begin_SQL {
	my $self = shift;
	my ($sql, $result, $throw, $maxrows, $winstart, $winsize,
	    $gen_my, $input_lref, @var) = @_;
	my $db_name = $self->{db_name};
	my $pkg = $self->{pkg};

	# Wenn Befehl mit ; abgeschlossen ist, ; entfernen
	$sql =~ s/;$//;

	my ($code, $var, $maxrows_cond, $winstart_cmd);
	$maxrows_cond='';
	$winstart_cmd='';
	
	my $fetch_method = $self->{dbi_version} eq '0.73' ?
			   'fetch' : 'fetchrow_arrayref';

	my $bind_list = '';
	if ( scalar (@{$input_lref}) ) {
		$bind_list = join (",", @{$input_lref});
	}

	if ( defined $var[0] ) {
		# Aha, wir haben wir ein SELECT Statement oder zumindest etwas,
		# was offensichtlich Rows zurueckliefert (sonst waeren wohl
		# kaum Variablen-Namen uebergeben worden :)

		$self->{type} = "select";
		$var = "\$".join (", \$", @var);

		$code =  qq {my ($var);\n} if $gen_my;
		$code .= qq {my \$cipp_sql_code = qq{$sql}; ${pkg}_sth = }.
			 qq {${pkg}::dbh->prepare ( \$cipp_sql_code );}."\n".
			 qq {die "$throw\t\$DBI::errstr\n\$cipp_sql_code" if \$DBI::errstr;}. "\n";
		$code .= qq {${pkg}_sth->execute($bind_list);}."\n".
			 qq {die "$throw\t\$DBI::errstr\n\$cipp_sql_code" if defined \$DBI::errstr;}."\n";

		if ( defined $maxrows ) {
			$code .= qq {${pkg}_maxrows=$maxrows;\n};
			$maxrows_cond = "${pkg}_maxrows-- > 0 and";
		}

		if ( defined $winstart ) {
			$code .= qq {${pkg}_maxrows=$winstart+$winsize;\n};
			$code .= qq {${pkg}_winstart=$winstart;\n};
			$maxrows_cond = "--${pkg}_maxrows > 0 and";
			$winstart_cmd =
				qq {next if --${pkg}_winstart }.
				qq {> 0;\n};
		}

		$code .= qq [SQL: while ( $maxrows_cond ${pkg}_ar = ].
			 qq [${pkg}_sth->$fetch_method ) {]."\n";
		$code .= qq [$winstart_cmd($var) = \@{${pkg}_ar};]."\n";
	} else {
		# Anscheinend handelt es sich um ein SINGLE Statment, dass
		# ausser einem einzelnen Wert nichts zurueckliefert wird

		if ( $bind_list ne '' ) {
			$bind_list = ", undef, $bind_list";
		}

		$self->{type} = "single";
		$code = "my \$cipp_sql_code = qq{$sql};\n";
		if ( defined $result ) {
			$result = "\$".$result if $result !~ /^\$/;
			$code .= 'my ' if $gen_my;
			$code .= qq{$result = };
		}
		$code .= qq{${pkg}::dbh->do( \$cipp_sql_code $bind_list);}."\n";
		$code .= qq{die "$throw\t\$DBI::errstr\n\$cipp_sql_code" if defined \$DBI::errstr;}."\n";
	}

	return $code;
}


sub End_SQL {
	my $self = shift;
	my $db_name = $self->{db_name};
	my $pkg = $self->{pkg};

	if ( $self->{type} eq "select" ) {
		return qq(}\n${pkg}_sth->finish;\n)
	} else {
		return "";
	}
}

sub Quote_Var {
	my $self = shift;
	my $db_name = $self->{db_name};
	my $pkg = $self->{pkg};
	my ($var, $db_var, $gen_my) = @_;

	my $code = '';
	$code = qq{my $db_var;\n} if $gen_my;
	
	$code .= qq{$var = undef if $var eq '';}."\n";
	$code .= qq{$db_var = ${pkg}::dbh->quote($var);}."\n";

	return $code;
}

sub Commit {
	my $self = shift;
	my ($throw) = @_;
	my $db_name = $self->{db_name};
	my $pkg = $self->{pkg};

	$code  = qq{${pkg}::dbh->commit();}."\n";
	$code .= qq{die "$throw\t\$DBI::errstr" if defined \$DBI::errstr;}."\n";

	return $code;
}

sub Rollback {
	my $self = shift;
	my ($throw) = @_;
	my $db_name = $self->{db_name};
	my $pkg = $self->{pkg};

	$code  = qq{${pkg}::dbh->rollback();}."\n";
	$code .= qq{die "$throw\t\$DBI::errstr" if defined \$DBI::errstr;}."\n";

	return $code;
}

sub Autocommit {
	my $self = shift;
	my ($status, $throw) = @_;
	my $db_name = $self->{db_name};
	my $pkg = $self->{pkg};

	if ( $status == 0 ) {
		$code = qq{${pkg}::dbh->{AutoCommit}=0;}."\n";
	} else {
		$code = qq{${pkg}::dbh->{AutoCommit}=1;}."\n";
	}

	return $code;
}

sub Get_DB_Handle {
	my $self = shift;
	my ($var, $my) = @_;
	my $db_name = $self->{db_name};
	my $pkg = $self->{pkg};

	$var = "my $var" if $my;

	$code  = qq{$var = ${pkg}::dbh;}."\n";

	return $code;
}



1;
__END__

=head1 NAME

CIPP::DB_DBI - CIPP database module to generate DBI code

=head1 DESCRIPTION

CIPP has a database code abstraction layer, so it can
generate code to access databases via different interfaces.

This module is used by CIPP to generate code to access
databases via DBI, version >= 0.93.

=head1 AUTHOR

Jörn Reder, joern@dimedis.de

=head1 COPYRIGHT

Copyright 1997-1999 dimedis GmbH, All Rights Reserved

This library is free software; you can redistribute it and/or modify
it under the same terms as Perl itself.

=head1 SEE ALSO

perl(1), CIPP (3pm)
