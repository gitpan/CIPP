package CIPP::Cache;

use strict;
use vars qw ( $VERSION );

$VERSION = "0.01";

sub is_clean {
	my $type = shift;
	my %par = @_;

	my ($dep_file) = $par{dep_file};

	return if not -f $dep_file;

	open (IN, $dep_file) or die "can't read $dep_file";
	my $line = <IN>;
	chomp $line;

	my ($src_file, $cache_file, $if_file);
	($src_file, $cache_file) = split(/\t/, $line);
#	print STDERR "$cache_file < $src_file : ";

	my $cache_file_mtime = (stat($cache_file))[9];
	if ( $cache_file_mtime < (stat($src_file))[9] ) {
		# cache is dirty, if cache_file is older than src_file
		close IN;
#		print STDERR "YES\n";
		return;
	}
#	print STDERR "OK\n";
	
	# now check include dependencies
	my $dirty;
	while (<IN>) {
		chomp;
		($src_file, $cache_file, $if_file) = split (/\t/, $_);
#		print STDERR "$cache_file < $src_file : ";
		if ( (stat($cache_file))[9] < (stat($src_file))[9] ) {
			# cache is dirty if one cache_file is older
			# than corresponding src_file
			$dirty = 1;
#			print STDERR "YES\n";
			last;
		}
#		print STDERR "OK\n";
		
#		print STDERR "$cache_file < $if_file : ";
		if ( $cache_file_mtime < (stat($if_file))[9] ) {
			# cache is dirty if the cache_file_mtime of
			# our object is older than one if_file
			# (indicates incompatible interface change)
#			print STDERR "YES\n";
			$dirty = 1;
			last;
		}
#		print STDERR "OK\n";
	}
	close IN;
	
	return not $dirty;
}

sub write_dep_file {
	my $type = shift;
	
	my %par = @_;

	my  ($dep_file,  $src_file,  $cache_file,  $include_files) =
	@par{'dep_file', 'src_file', 'cache_file', 'include_files'};
	
	# -------------------------------------------------------------
	# Format of the dep_file:
	# Line:		Fields:
	# -------------------------------------------------------------
	#  1		src_file       cache_file
	#  2..n		inc_src_file   inc_cache_file  inc_iface_file
	# -------------------------------------------------------------
	
	open (OUT, "> $dep_file") or die "can't write $dep_file";
	
	print OUT "$src_file\t$cache_file\n";
	
	foreach my $entry ( @{$include_files} ) {
		print OUT $entry,"\n";
	}
	close OUT;

	1;
}

sub add_used_includes {
	my $type = shift;
	my %par = @_;

	my $dep_file      = $par{dep_file};
	my $used_includes = $par{used_includes};

	return if not -f $dep_file;

	open (IN, $dep_file) or die "can't read $dep_file";
	my $line = <IN>;
	chomp $line;

	my $src_file;
	while (<IN>) {
		chomp;
		($src_file) = split (/\t/, $_, 2 );
		$used_includes->{$src_file} = $_;
	}
	close IN;
	
	return;
}

1;
