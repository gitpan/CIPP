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
