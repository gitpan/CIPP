package CIPP::Request;

use strict;
use vars qw ( $VERSION %INCLUDE_SUBS %INCLUDE_SUBS_LOADED );

$VERSION = "0.01";

# this hash takes anonymous code references to loaded
# include subroutines ( name => code reference )
%INCLUDE_SUBS = ();

# this hash takes stores the time of loading a sub
# ( name => timestamp )
%INCLUDE_SUBS_LOADED = ();

sub new {
	my $type = shift;
	
	my ($apache_request) = @_;
	
	my $self = {
		# Apache request object
		apache_request => $apache_request,
		
		# cache directory for preprocessed includes
		cache_dir => $apache_request->dir_config ("cache_dir"),
		
		# subroutines, loaded during this request
		loaded_subroutines => {},
	};
	
	return bless $self, $type;
}

sub call_include_subroutine {
	my $self = shift;
	
	my %par = @_;
	
	# take parameters
	my ($file, $input, $output) = @par{'file', 'input', 'output'};
	
	# load the subroutine
	my $sub = $self->load_include_subroutine ($file);
	
	# excecute the subroutine
	my $output_href = &$sub ($self, $input);

	# return output parameters
	foreach my $name ( keys %{$output} ) {
		if ( ref $output_href->{$name} eq 'SCALAR' or
		     ref $output_href->{$name} eq 'REF' ) {
#			print STDERR "$name: scalar\n";
			${$output->{$name}} = ${$output_href->{$name}};
		} elsif ( ref $output_href->{$name} eq 'ARRAY' ) {
#			print STDERR "$name: array\n";
			@{$output->{$name}} = @{$output_href->{$name}};
		} elsif ( ref $output_href->{$name} eq 'HASH' ) {
#			print STDERR "$name: hash\n";
			%{$output->{$name}} = %{$output_href->{$name}};
		} else {
			print STDERR "$name: ", ref($output_href->{$name}), "\n";
		}
	}
	
	1;
}

sub load_include_subroutine {
	my $self = shift;
	
	my ($file) = @_;
	
	# key of subroutine
	my $sub_key = $file;
	
	# no need to check or do anything if already loaded during this request
	# (changes made during one request are silently ignored)
	return $INCLUDE_SUBS{$sub_key} if $self->{loaded_subroutines}->{$sub_key};
	
	# filename of subroutine
	my $perl_code_file = $file;
	
	# subroutine already loaded and up to date?
	# then we can return the sub reference immediately
	if ( defined $INCLUDE_SUBS{$sub_key} ) {
		my $load_time = $INCLUDE_SUBS_LOADED{$sub_key};
		my $mtime = (stat($perl_code_file))[9];
		return $INCLUDE_SUBS{$sub_key} if $mtime < $load_time;
	}
	
	# otherwise load the subroutine perl code file
	open (PC, $perl_code_file) or die "INCLUDE\tcan't read $perl_code_file";
	my $perl_code;
	while (<PC>) {
		$perl_code .= $_;
	}
	close PC;
	
	# evalulate the code
	my $sub = eval_perl_code (\$perl_code);
	die "INCLUDE\truntime error loading include file '$perl_code_file':\n$@"
		if $@;
	
	# store load time in global hash
	$INCLUDE_SUBS_LOADED{$sub_key} = time;

	# store subroutine in global hash
	$INCLUDE_SUBS{$sub_key} = $sub;
	
	# ok, subsequent include subroutine calls can call the subroutine
	# immediately, without the whole load and cache check stuff
	$self->{loaded_subroutines}->{$sub_key} = 1;

	return $sub;

	1;
}

sub eval_perl_code {
	# do the eval in this mini subroutine, so NO lexicals
	# are in the scope of it.
	# checking of $@ has to be done by the caller
	eval ${$_[0]};
}

1;
