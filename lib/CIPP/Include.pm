# $Id: Include.pm,v 1.3 2001/03/27 18:37:15 joern Exp $

package CIPP::Include;

use Carp;
use strict;
use File::Path;
use File::Basename;
use Data::Dumper;
use CIPP::Cache;

use vars qw ( $VERSION );

$VERSION = "0.01";

my $DEBUG = 0;

sub new {
	my $type = shift;
	
	my %par = @_;
	
	# take parameters
	my  ($CIPP,  $name,  $filename,  $gen_my,  $input,  $output) =
	@par{'CIPP', 'name', 'filename', 'gen_my', 'input', 'output'};
	
	$DEBUG && print STDERR "new INCLUDE: $name\n";
	
	my $self = bless {
		# CIPP object
		CIPP => $CIPP,
		
		# name of the include
		name => $name,
		
		# filename of the include,
		filename => $filename,
		
		# declare output variables with my?
		gen_my => $gen_my,
		
		# input parameters of this include call
		input => $input,
		
		# output parameters of this include call
		output => $output,
		
		# cache directory
		cache_dir => $CIPP->{apache_mod}->dir_config('cache_dir'),
		
		# document root
		document_root => $CIPP->{apache_mod}->document_root,
		
		# interface of this include (cached here)
		include_interface => undef,
		
		# apache request object
		apache_request => $CIPP->{apache_mod},
		
	}, $type;
	
	my $cache_filename     = $self->get_cache_filename ($filename);
	my $interface_filename = $self->get_interface_filename ($filename);
	my $dep_filename       = $self->get_dep_filename ($filename);

	$self->{cache_filename}     = $cache_filename;
	$self->{interface_filename} = $interface_filename;
	$self->{dep_filename}       = $dep_filename;

	my ($atime,$mtime) = (stat($interface_filename))[8,9] if -f $interface_filename;

	$self->{last_interface_atime} = $atime;
	$self->{last_interface_mtime} = $mtime;
	
	return $self;
}

sub get_cache_filename {
	my $self = shift;

	my ($filename) = @_;
	
	my $CIPP = $self->{CIPP};
	
	my $cache_dir     = $self->{cache_dir};
	my $document_root = $self->{document_root};
	
	$filename =~ s!$document_root/!!;
	
	# the cache filename consists of the object name,
	# the state of 'use_strict', 'gen_print' and 'profile', because code
	# production depends on them.
	my $cache_filename = "$cache_dir/$filename-".
			     ($CIPP->{use_strict}?'strict':'nostrict').
			     "-".
			     ($CIPP->{gen_print}?'print':'noprint').
			     "-".
			     ($CIPP->{profile}?'profile':'noprofile').
			     ".code";
	return $cache_filename;
}

sub get_interface_filename {
	my $self = shift;
	
	my ($name) = @_;
	
	my $filename = $self->get_cache_filename ($name);
	$filename =~ s/\.code$/.iface/;
	
	return $filename;
}

sub get_dep_filename {
	my $self = shift;
	
	my ($name) = @_;
	
	my $filename = $self->get_cache_filename ($name);
	$filename =~ s/\.code$/.dep/;
	
	return $filename;
}

sub process {
	my $self = shift;
	
	# preprocess, if needed and return, if an error occured
	return if not $self->cipp_preprocessed_ok;
	
	# lets check the interface and return, if it is not correct
	if ( not $self->interface_is_correct ) {
		$DEBUG && print STDERR "INTERFACE INCORRECT: $self->{name}\n";
		return;
	} else {
		$DEBUG && print STDERR "INTERFACE CORRECT: $self->{name}\n";
	}
	
	# ok, everything ok and up-to-date, generate the include call
	$self->generate_include_call_code;
	
	# return the interface filename, for dependecny purposes
	return $self->{filename};	
}

sub cipp_preprocessed_ok {
	my $self = shift;

	my $name         = $self->{name};
	my $include_file = $self->{filename};
	my $CIPP         = $self->{CIPP};

	# update used_macros information with "us"
	
	$CIPP->{used_macros}->{$include_file} = "$include_file\t$self->{cache_filename}\t$self->{interface_filename}";

	# do we really need to preprocess this include?
	if ( CIPP::Cache->is_clean ( dep_file => $self->{dep_filename} ) ) {
		# ok, we are clean, but we must return the includes,
		# we are using, so our "Includer" can record this
		# in its dependency list.
		#
		# which databases we used is recorder later,
		# in the interface_is_correct method, because
		# databases are an interface information which
		# is stored in the .iface file
		CIPP::Cache->add_used_includes (
			dep_file      => $self->{dep_filename} ,
			used_includes => $CIPP->{used_macros},
		);

		$DEBUG && print STDERR "$name: no need to preprocess\n";

		return 1;
	}

	$DEBUG && print STDERR "$name: starting preprocess\n";

	# yes, we need
	my $perl_code;

	my $name         = $self->{name};
	my $include_file = $self->{filename};

	my $INCLUDE = new CIPP
		($include_file, \$perl_code, $CIPP->{projects},
		 $CIPP->{db_driver}, $CIPP->{mime_type},
		 $CIPP->{default_db}, $CIPP->{call_path}.
		 "[".$CIPP->{input}->Get_Line_Number."]:".$name,
		 $CIPP->{skip_header_line}, $CIPP->{debugging},
		 "include", $CIPP->{use_strict},
		 $CIPP->{persistent}, $CIPP->{apache_mod},
		 $CIPP->{project}, $CIPP->{use_inc_cache},
		 $CIPP->{lang});

	# set include into profiling state, if needed
	$INCLUDE->{profile} = 'deep' if $CIPP->{profile} eq 'deep';

	# everything initialized ok?
	if ( ! $INCLUDE->Get_Init_Status ) {
		$CIPP->ErrorLang ("INCLUDE", 'include_cipp_init');
		return;
	}

	# preprocess it
	$INCLUDE->Set_Write_Script_Header (0);
	$INCLUDE->Preprocess ();

	# store interface
	my $interface = $self->store_include_interface ($INCLUDE);

	# update dependencies
	$self->write_include_dependencies ($INCLUDE);

	# Hash der benutzten Macros aus der Liste des Macros aktualisieren
	my ($macro, $files);
	if ( defined $INCLUDE->Get_Used_Macros() ) {
		while ( ($macro, $files) = each %{$INCLUDE->Get_Used_Macros()} ) {
			$CIPP->{used_macros}{$macro} = $files;
		} 
	}

	# Hash der benutzten Datenbanken aus der Liste des Macros aktualisieren
	my $db; my $foo;
	if ( defined $INCLUDE->Get_Used_Databases() ) {
		while ( ($db, $foo) = each %{$INCLUDE->Get_Used_Databases()} ) {
			$CIPP->{used_databases}{$db} = 1;
		} 
	}

	# Hash der benutzten Bilder aus der Liste des Macros aktualisieren
	my $image;
	if ( defined $INCLUDE->Get_Used_Images() ) {
		while ( ($image, $foo) = each %{$INCLUDE->Get_Used_Images()} ) {
			$CIPP->{used_images}{$image} = 1;
		} 
	}

	# Hash der benutzten Configs aus der Liste des Macros aktualisieren
	my $config;
	if ( defined $INCLUDE->Get_Used_Configs() ) {
		while ( ($config, $foo) = each %{$INCLUDE->Get_Used_Configs()} ) {
			$CIPP->{used_configs}{$config} = 1;
		} 
	}

	# error checking
	if ( defined $INCLUDE->Get_Messages() ) {
		push @{$CIPP->{message}}, @{$INCLUDE->Get_Messages()};
	}
	if ( ! $INCLUDE->Get_Preprocess_Status() ) {
		$CIPP->Set_Preprocess_Status(0);
		return;
	}

	# generate profiling code?
	if ( $CIPP->{profile} ) {
		$perl_code =
			$CIPP->get_profile_start_code().
			$perl_code.
			$CIPP->get_profile_end_code ( "INCLUDE", $name );
	}
	

	$self->write_include_subroutine (
		perl_code_sref => \$perl_code,
		interface => $interface
	);

	if ( $self->{interfaces_are_compatible} and $self->{last_interface_atime} ) {
		# set back timestamps
		my $interface_filename = $self->{interface_filename};
		utime $self->{last_interface_atime}, $self->{last_interface_mtime},
		      $interface_filename;
		$DEBUG && print STDERR "touch $self->{last_interface_mtime}, $interface_filename\n";
	}
	return 1;
}

sub write_include_subroutine {
	my $self = shift;
	
	my %par = @_;
	
	my ($perl_code_sref, $interface) = @par{'perl_code_sref','interface'};

	# write include subroutine
	my $cache_filename = $self->{cache_filename};
	$self->make_path ($cache_filename);
	open (OUT, "> $cache_filename") or die "can't write $cache_filename";
	print OUT "sub {\n";
	print OUT 'my $cipp_request_object = shift;'."\n";
	print OUT 'my $cipp_apache_request = $cipp_request_object->{apache_request};'."\n";

	# code for input parameters
	
	foreach my $var ( values %{$interface->{input}} ) {
		my $name = $var;
		$name =~ s/^(.)//;
		my $deref = $1;
		
		if ( $deref eq '$' ) {
			print OUT "my $var = ".'$_[0]->{'.$name.'};'."\n";
		} else {
			print OUT "my $var = $deref\{".'$_[0]->{'.$name.'}};'."\n";
		}
	}
	
	# code for optional parameters
	foreach my $var ( values %{$interface->{optional}}) {
		my $name = $var;
		$name =~ s/^(.)//;
		my $deref = $1;
		
		if ( $deref eq '$' ) {
			print OUT "my $var = ".'$_[0]->{'.$name.'};'."\n";
		} else {
			# don't write: my $var = ${$foo} if defined $foo
			# this produce strange behaviour (at least unter Perl 5.6.0)
			# The dereferenced memory seems to live outside the
			# scope of this subroutine.
			print OUT "my $var;\n";
			print OUT "$var = $deref\{".'$_[0]->{'.$name.'}} if defined $_[0]->{'.$name.'};'."\n";
		}
	}
	# declaration of output parameters
	if ( keys %{$interface->{output}} ) {
		my $code;
		foreach my $var ( values %{$interface->{output}} ) {
			$code .= "$var,";
		}
		$code =~ s/,$//;
		print OUT "my ($code);\n";
	}

	print OUT "eval {\n";

	# the body of our include/subroutine

	print OUT $$perl_code_sref;

	print OUT "};\n";
	print OUT 'die "INCLUDE\t'.$self->{cache_filename}.'\n$@" if $@'.";\n";

	# returning output paramters
	if ( keys %{$interface->{output}} ) {
		my $code;
		my $name;
		foreach my $var ( values %{$interface->{output}} ) {
			$name = $var;
			$name =~ s/^(.)//;
			$code .= "$name => \\$var,";
		}
		$code =~ s/,$//;
		print OUT "\n  return { $code };\n";
	}

	# close sub
	print OUT "};\n";
	
	close OUT;

	# ok, preprocessing was successfull
	return 1;
}

sub store_include_interface {
	my $self = shift;
	
	my ($INCLUDE) = @_;
	
	my $param_input    = $INCLUDE->Get_Include_Inputs() || {};
	my $param_optional = $INCLUDE->Get_Include_Optionals() || {};
	my $param_output   = $INCLUDE->Get_Include_Outputs() || {};
	my $param_bare     = $INCLUDE->Get_Include_Bare() || {};
	my $databases      = $INCLUDE->Get_Used_Databases() || {};

	my $filename       = $self->{interface_filename};

	my $old_interface  = $self->get_include_interface  if -f $filename;
	
	$self->make_path ($filename);

	open (OUT, "> $filename") or die "INCLUDE\tcan't write $filename";
	print OUT join (":", %{$param_input}), "\n";
	print OUT join (":", %{$param_optional}), "\n";
	print OUT join (":", %{$param_output}), "\n";
	print OUT join (":", %{$param_bare}), "\n";
	print OUT join (":", %{$databases}), "\n";
	close OUT;

	my $new_interface = {
		input     => $param_input,
		optional  => $param_optional,
		output    => $param_output,
		noquote   => $param_bare,
		databases => $databases,
	};

	$self->{interfaces_are_compatible} = $self->interfaces_are_compatible (
		old_interface => $old_interface,
		new_interface => $new_interface
	);

	return $self->{include_interface} = $new_interface;
}	

sub interfaces_are_compatible {
	my $self = shift;
	
	my %par = @_;
	my ($oi, $ni) = @par{'old_interface', 'new_interface'};
	
	my $par;
	my $incompatible;
	my $name = $self->{name};
	
	# 1. incompatible, if we have a new INPUT parameter,
	#    or type has changed
		
	foreach $par ( keys %{$ni->{input}} ) {
		return if $oi->{input}->{$par} ne $ni->{input}->{$par};
	}
	
#	$DEBUG && print STDERR "interface_compatible ($name) 1: no new INPUT parameters\n";

	# 2. an INPUT parameter was removed, but is no
	#    optional parameter (of same type)
	
	foreach $par ( keys %{$oi->{input}} ) {
		return if $oi->{input}->{$par} ne $ni->{input}->{$par} and
		          $oi->{input}->{$par} ne $ni->{optional}->{$par};
	}
	
#	$DEBUG && print STDERR "interface_compatible ($name) 2: no removed INPUT parameters\n";

	# 3. removal of an OPTIONAL parameter (or type switch)?
	
	foreach $par ( keys %{$oi->{optional}} ) {
		return if $oi->{optional}->{$par} ne $ni->{optional}->{$par};
	}
	
#	$DEBUG && print STDERR "interface_compatible ($name) 3: no removed OPTIONAL parameters\n";

	# 4. removal of an OUTPUT parameter?
	
	foreach $par ( keys %{$oi->{output}} ) {
		return if $oi->{output}->{$par} ne $ni->{output}->{$par};
	}
	
#	$DEBUG && print STDERR "interface_compatible ($name) 4: no removed OUTPUT parameters\n";

	# 5. TODODODODO: databases check

	return 1;
}

sub get_include_interface {
	my $self = shift;

	my $filename = $self->{interface_filename};

	return $self->{include_interface}
		if defined $self->{include_interface};

	my $line;
	open (IN, $filename)
		or confess "INCLUDE\tCan't load interface file '$filename'";
	
	# input parameters
	chomp ($line = <IN>);
	my %input = split(":", $line);
	
	# optional parameters
	chomp ($line = <IN>);
	my %optional = split(":", $line);
	
	# output parameters
	chomp ($line = <IN>);
	my %output = split(":", $line);
	
	# noquote parameters
	chomp ($line = <IN>);
	my %bare = split(":", $line);
	
	# databases
	chomp ($line = <IN>);
	my %databases = split(":", $line);
	
	# close file
	close IN;
	
	# store and return
	return $self->{include_interface} = {
		input     => \%input,
		optional  => \%optional,
		output    => \%output,
		noquote   => \%bare,
		databases => \%databases,
	};

	1;
}

sub write_include_dependencies {
	my $self = shift;
	
	my ($INCLUDE) = @_;

	my $includes  = $INCLUDE->Get_Used_Macros;
	my @include_files = values %{$includes};

	CIPP::Cache->write_dep_file (
		src_file      => $self->{filename},
		dep_file      => $self->{dep_filename},
		cache_file    => $self->{cache_filename},
		include_files => \@include_files,
	);
	
	1;
}

sub interface_is_correct {
	my $self = shift;
	
	# load interface information
	my $interface = $self->get_include_interface;
	
	# notify called object about our databases
	my $CIPP = $self->{CIPP};
	foreach my $db ( keys %{$interface->{databases}} ) {
		$CIPP->{used_databases}->{$db} = 1;
	}
	
	my $error;

	my $CIPP   = $self->{CIPP};
	my $input  = $self->{input};
	my $output = $self->{output};
	
#	$DEBUG && print STDERR "Include Interface: ", Dumper ($interface);
#	$DEBUG && print STDERR "input: ", Dumper ($input);
#	$DEBUG && print STDERR "output: ", Dumper ($output);

	# any unknown input parameters?
	my @unknown_input;
	foreach my $par ( keys %{$input} ) {
		if ( not defined $interface->{input}->{$par} and
		     not defined $interface->{optional}->{$par} ) {
			$CIPP->ErrorLang ("INCLUDE", 'include_unknown_in_par', [$par]);
			$error = 1;
		}
	}
	
	# do we miss some parameters?
	foreach my $par ( keys %{$interface->{input}} ) {
		if ( not defined $input->{$par} ) {
			$CIPP->ErrorLang ("INCLUDE", 'include_missing_in_par', [$par]);
			$error = 1;
		}
	}

	# any unknown output parameters?
	foreach my $par ( keys %{$output} ) {
		if ( not defined $interface->{output}->{$par} ) {
			$CIPP->ErrorLang ("INCLUDE", 'include_unknown_out_par', [$par]);
			$error = 1;
		}
	}

	$DEBUG && print STDERR "$self->{name}: interface check. error=$error\n";

	return not $error;	
}

sub generate_include_call_code {
	my $self = shift;

	$DEBUG && print STDERR "GENERATE INCLUDE CALL CODE: $self->{name}\n";

	my $interface = $self->get_include_interface;
	
	my $code;
	
	# get output parameters
	my $output = $self->{output};
	if ( keys %{$output} and $self->{gen_my} ) {
		$code .= "my (";
		foreach my $var_name ( values %{$output} ) {
			$code .= "$var_name,";
		}
		$code =~ s/,$//;
		$code .= ");\n";
	}

	# call subroutine
	$code .= '$cipp_request_object->call_include_subroutine ('."\n";
	$code .= "\tfile => '$self->{cache_filename}',\n";
	$code .= "\tinput => {\n";
	
	# input parameters
	my $input = $self->{input};
	my $quote_start;
	my $quote_end;
	my $val;
	foreach my $name ( keys %{$input} ) {
		my $var = $interface->{input}->{$name} ||
		          $interface->{optional}->{$name};
		$var =~ /^(.)/;
		my $type = $1;

		if ( $type eq '$' ) {
		     	# scalar parameter
			$quote_start = defined $interface->{noquote}->{$name} ? '' : 'qq{';
			$quote_end   = defined $interface->{noquote}->{$name} ? '' : '}';
			$val = $input->{$name};
#			($val = $input->{$name}) =~ s/\{/\\{/g
#				unless defined $interface->{noquote}->{$name};
			$code .= "\t\t$name => $quote_start$val$quote_end,\n";

		} elsif ( $type eq '@' ) {
			# list parameter
			$code .= "\t\t$name => [ $input->{$name} ],\n";

		} elsif ( $type eq '%' ) {
			# hash parameter
			$code .= "\t\t$name => { $input->{$name} },\n";
		}
	}
	
	$code .= "\t},\n";
	
	# tell which output parameters we want
	if ( keys %{$output} ) {
		$code .= "\toutput => {\n";
		my $type;
		foreach my $name ( keys %{$output} ) {
			my $var = $output->{$name};
			$code .= "\t\t\t'$name' => \\$var,\n";
		}
		$code .= "\t\t},\n";
	}
	
	$code .= ");\n";
	
	$self->{CIPP}->{output}->Write ( $code );

#	$DEBUG && print STDERR "include call code:\n$code\n\n";

	1;
}

sub make_path {
	my $self = shift;
	
	my ($filename) = @_;
	my $dir = dirname $filename;
	
	return if -d $dir;

	mkpath ($dir, 0, 0700)
		or confess "can't mkpath '$dir': $!";
	
	1;
}
	
	
1;
