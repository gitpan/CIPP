#==============================================================================
#
# MODUL
#       CIPP::DB_DBI_old
#
# METHODEN
#       siehe CIPP_DB.interface
#
#==============================================================================
# COPYRIGHT
#       (c) 1997-1998 dimedis GmbH, All Rights Reserved
#       programming by Joern Reder
#
#------------------------------------------------------------------------------
#
# MODIFICATION HISTORY
#	01.07.1998 0.1.0.0 joern
#		+ Veerbung von CIPP_DB_DBI
#		+ Heruntersetzen der DBI Versionsnummer im Konstruktor
#
#	16.01.1999 0.2.0.0 joern
#		+ umbenannt con CIPP_DB_DBI_old nach CIPP::DB_DBI_old
#------------------------------------------------------------------------------

package CIPP::DB_DBI_old;

use CIPP::DB_DBI;
@ISA = qw( CIPP::DB_DBI );
$VERSION  = "0.2";

sub new {
	my ($type) = shift;
	my ($db_name, $persistent) = @_;

	my $self = $type->SUPER::new ($db_name, $persistent);

	$self->{dbi_version} = '0.73';

	return bless $self, $type;
}

# Alle anderen Methoden werden von DBI übernommen
# Dort wird je nach gesetzter Versionsnummer Code für der DBI Versionsnummer
# entsprechende Spezifikation generiert
#
# Gegenüber CIPP bleibt dies alles transparent, da dieser Treiber dort
# genauso wie alle anderen CIPP-DB-Driver eingebunden wird.

1;
__END__

=head1 NAME

CIPP::DB_DBI_old - CIPP database module to generate old DBI (v0.73) code

=head1 DESCRIPTION

CIPP has a database code abstraction layer, so it can
generate code to access databases via different interfaces.

This module is used by CIPP to generate code to access
databases via DBI, version 0.73. (This is the version shipped
with Oracle Application Server 4.0)

=head1 AUTHOR

Jörn Reder, joern@dimedis.de

=head1 COPYRIGHT

Copyright 1997-1999 dimedis GmbH, All Rights Reserved

This library is free software; you can redistribute it and/or modify
it under the same terms as Perl itself.

=head1 SEE ALSO

perl(1), CIPP (3pm)
