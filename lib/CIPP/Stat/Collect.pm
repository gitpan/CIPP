package CIPP::Stat::Collect;

# Runtime statistics for CIPP programs. Simply a Time::HiRes based
# logging of events, related to CIPP objects. CIPP::Request uses
# it for tracking CIPP page execution, include subroutine loading
# and include subroutine execution.

use strict;
use Time::HiRes qw(time);
use FileHandle;

use vars qw ( $VERSION  );

$VERSION = "0.01";

# Each process has its own stat file. So it is legal,
# to store the filename of the stat file in this lexical
# class variable. (assigned in the constructor).

my $STAT_FILE;

# This END block deletes the stat file. When the process dies,
# we don't need its status information anymore.

END {
  unlink $STAT_FILE;
}

sub request {
	my $type = shift;
	
	my %par = @_;
	
	my  ($object,  $cache_dir) =
	@par{'object', 'cache_dir'};
	
	my $stat_dir  = "$cache_dir/.stats";
	my $stat_file = "$stat_dir/$$";

	my $fh = new FileHandle;
	mkdir ($stat_dir, 0750) if not -d $stat_dir;
	open ($fh, ">> $stat_file") or die "can't write $stat_file";

	$object =~ s/\?.*//;

	my $self = bless {
		object    => $object,
		stat_dir  => $stat_dir,
		stat_file => "$stat_dir/$$",
		cache_dir => $cache_dir,
		fh        => $fh,
	}, $type;
	
	$self->log ("request_start");

# 	this works, too. WHY???
#	END { unlink $stat_file };

	$STAT_FILE = $stat_file;
	
	return $self;
}

sub DESTROY {
	my $self = shift;
	
	$self->log ("request_end");
}

sub log {
	my $self = shift;
	
	my $fh = $self->{fh};

	my ($event, $par) = @_;

	# remove cache_dir
	$par =~ s/^$self->{cache_dir}//o;

	# remove state flags (strict, profile, print)
	$par =~ s/-(no)?strict.*$//;

	print $fh time,"\t$self->{object}\t$event\t$par\n";
}


1;
