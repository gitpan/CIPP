# $Id: NewSpirit.pm,v 1.13 2003/08/07 08:07:30 joern Exp $

package CIPP::Runtime::NewSpirit::Project;

use strict;
use Carp;

my $DEBUG = -f "/tmp/cipp.debug.enable";

my %PROJECT_INSTANCES;

sub get_project			{ shift->{project}			}

sub get_prod_dir		{ shift->{config}->{prod_dir}		}
sub get_cgi_dir			{ shift->{config}->{prod_dir}."/cgi-bin"}
sub get_doc_dir			{ shift->{config}->{prod_dir}."/htdocs"	}
sub get_config_dir		{ shift->{config}->{config_dir}		}
sub get_inc_dir			{ shift->{config}->{inc_dir}		}
sub get_lib_dir			{ shift->{config}->{lib_dir}		}
sub get_log_dir			{ shift->{config}->{log_dir}		}
sub get_log_file		{ shift->{config}->{log_file}		}
sub get_cgi_url			{ shift->{config}->{cgi_url}		}
sub get_doc_url			{ shift->{config}->{doc_url}		}
sub get_url_par_delimiter	{ shift->{config}->{url_par_delimiter}	}
sub get_http_header		{ shift->{config}->{http_header}	}
sub get_add_lib_dirs		{ shift->{config}->{add_lib_dirs}  ||[]	}
sub get_add_prod_dirs		{ shift->{config}->{add_prod_dirs} ||[]	}
sub get_error_show		{ shift->{config}->{error_show}		}
sub get_error_text		{ shift->{config}->{error_text}		}
sub get_utf8			{ shift->{config}->{utf8}		}
sub get_cipp_compiler_version	{ shift->{config}->{cipp_compiler_version}}

sub get_config			{ shift->{config}			}
sub get_request_cnt		{ shift->{request_cnt}			}
sub get_init_error_message	{ shift->{init_error_message}		}

sub set_config			{ shift->{config}		= $_[1]	}
sub set_request_cnt		{ shift->{request_cnt}		= $_[1]	}
sub set_init_error_message	{ shift->{init_error_message}	= $_[1]	}

sub debug {
	return if not $DEBUG;
	shift;
	require File::Basename;
	open (DEBUG,">>/tmp/cipp.debug.log") or return;
	print DEBUG scalar(localtime(time)),
		    " $$ '",File::Basename::basename($0),"'\t",
		    join (" ", @_), "\n";
	close DEBUG;
	1;
}

sub init {
	my $type = shift;
	my %par = @_;
	my  ($back_prod_path, $project) =
	@par{'back_prod_path','project'};

	# only one instance per process and project
	if ( defined $PROJECT_INSTANCES{$project} ) {
		my $self = $PROJECT_INSTANCES{$project};
		unshift @INC, $self->get_lib_dir;
		unshift @INC, @{$self->get_add_lib_dirs};
		unshift @INC, map { "$_/lib" } @{$self->get_add_prod_dirs};
		$self->debug ("Project '$project' initialized FROM CACHE.");
		$self->debug ("INC PATH:", @INC);
		return 1;
	}

	# determine relative project prod root path
	$0 =~ m!^(.*)[/\\][^/\\]+$!;
	my $prod_dir = "$1/$back_prod_path";
	
	my $self = bless {
		project	       => $project,
		request_cnt    => 0,
		config	       => {},
	}, $type;
	
	# read base config to get absolute path of project root
	$self->read_base_config (
		filename => "$prod_dir/config/cipp.conf"
	) or return;
	
	# add project lib dir to @INC
	unshift @INC, $self->get_lib_dir;
	
	# add additional configured project's lib dirs to @INC
	unshift @INC, map { "$_/lib" } @{$self->get_add_prod_dirs};

	# add additional configured dirs to @INC
	unshift @INC, @{$self->get_add_lib_dirs};
	
	# debugging
	$self->debug ("Project '$project' initialized FIRST TIME.");
	$self->debug ("INC PATH:", @INC);

	# register project instance
	$PROJECT_INSTANCES{$project} = $self;

	# load Encode module if utf8 is set and we have Perl >= 5.8.0
	if ( $self->get_utf8 and $] >= 5.008 ) {
		require Encode;
		binmode STDOUT, ":utf8";
	} else {
		binmode STDOUT;
	}

	1;
}

sub handle {
	my $class = shift;
	my %par = @_;
	my ($project) = @par{'project'};
	$class->debug ("Handle of project '$project' requested.");
	return $PROJECT_INSTANCES{$project}
}

sub read_base_config {
	my $self = shift;
	my %par = @_;
	my ($filename) = @par{'filename'};
	
	$filename ||= $self->get_config_dir."/cipp.conf";
	
	my $config = do $filename;
	
	if ( not ref $config ) {
		if ( not -f $filename ) {
			$self->set_init_error_message ("CIPP base config '$filename' not found.");
		} elsif ( not -r $filename ) {
			$self->set_init_error_message ("CIPP base config '$filename' not readable.");
		} else {
			$self->set_init_error_message ("CIPP base config '$filename' has wrong format.");
		}
		
		$self->init_error;

		return;
	}

	$self->set_config ($config);

	1;	
}

sub new_request {
	my $self = shift;
	my %par = @_;
	my  ($program_name, $mime_type) =
	@par{'program_name','mime_type'};

	$self->set_request_cnt ( $self->get_request_cnt + 1 );

	my $request = CIPP::Runtime::NewSpirit::Request->new (
		project_handle => $self,
		program_name   => $program_name,
		mime_type      => $mime_type,
	);

	$request->init;

	$CIPP::request = $request;
}

sub init_error {
	my $self = shift;
	
	my $message = $self->get_init_error_message;
	my $project = $self->get_project;

	print "Content-type: text/html\n\n";
	print "<h1>Project initialization error</h1>\n";
	print "<p><b>Project:</b><blockquote>$project</blockquote>\n";
	print "<p><b>Message:</b><blockquote>$message</blockquote>\n";
	
	1;
}

package CIPP::Runtime::NewSpirit::Request;

use vars qw ( @ISA );
use strict;
use Carp;

use CIPP::Runtime::Request;
@ISA = qw ( CIPP::Runtime::Request );

sub get_mime_type		{ shift->{mime_type}			}
sub set_mime_type		{ shift->{mime_type}		= $_[1]	}

sub new {
	my $type = shift;
	my %par = @_;
	my ($mime_type) = @par{'mime_type'};
	
	my $self = bless $type->SUPER::new(@_), $type;

	$self->set_mime_type ($mime_type);

	if ( $self->get_project_handle->get_utf8 and $] >= 5.008 ) {
		binmode STDOUT, ":utf8";
	} else {
		binmode STDOUT;
	}

	return $self;
}

sub init {
	my $self = shift;
	
	# change to program dir
	$0 =~ m!^(.*)[/\\][^/\\]+$!;
	chdir $1 if $1;
	
	1;
}

sub print_http_header {
	my $self = shift;

	my $mime_type = $self->get_mime_type;

	if ( $mime_type =~ m!text/html! and $self->get_utf8 ) {
		$mime_type = "text/html; charset=utf-8";
	}

	if ( $mime_type ne 'cipp/dynamic' ) {
		$self->get_http_header->{'content-type'} = $mime_type;
		$self->SUPER::print_http_header(@_);
	}

	1;
}	

sub get_db_config {
	my $self = shift;
	my %par = @_;
	my ($db) = @par{'db'};
	
	my $filename = $self->get_project_handle->get_config_dir."/$db.db-conf";

	if ( not -e $filename ) {
		foreach my $config_dir ( map   { $_."/config" }
				         @{$self->get_project_handle
					        ->get_add_prod_dirs} ) {
			$filename = "$config_dir/$db.db-conf";
			last if -e $filename;
		}

		# set full_path to this project's config dir, if not
		# found. This produces an error message which belongs
		# to this project.
		$filename = $self->get_config_dir."/$db.db-conf" if not -e $filename;
	}

	my $config = do $filename;
	
	if ( not ref $config ) {
		croak "Database config file '$filename' not found or wrong format.";
	}

	return $config;
}

sub resolve_filename {
	my $self = shift;
	my %par = @_;
	
	my ($name, $throw, $type) = @par{'name','throw','type'};
	
	$throw ||= "resolve_filename";

	my $orig_name = $name;
	$name =~ s!^[^\.]+\.!!;

	my $filename;
	
	if ( $type eq 'cipp-config' ) {
		$filename = $self->get_config_dir."/".$name.".config";

		if ( not -e $filename ) {
			foreach my $config_dir ( map   { $_."/config" }
				        	 @{$self->get_project_handle
						        ->get_add_prod_dirs} ) {
				$filename = "$config_dir/$name.config";
				last if -e $filename;
			}

			# set full_path to this project's config dir, if not
			# found. This produces an error message which belongs
			# to this project.
			$filename = $self->get_config_dir."/".$name.".config"
				if not -e $filename;
		}

	} else {
		$self->error (
			message => "Unknown object type '$type'"
		);
	}

	die "$throw\tFile '$filename' for object '$orig_name', type '$type' not found"
		if not -f $filename;
	
	return $filename;
}

sub get_include_name {
	my $self = shift;
	my %par = @_;
	my ($filename) = @par{'filename'};

	$filename =~ s/\.[^.]+$//;
	$filename =~ s!/!.!g;
	$filename = $self->get_project_handle->get_project.".$filename";
	
	return $filename;
}

sub get_object_url {
	my $self = shift;
	my %par = @_;
	my ($name, $throw) = @par{'name','throw'};
	
	$throw ||= "geturl";
	
	my $object = $name;
	my $project = $self->get_project_handle->get_project;
	my $cgi_dir = $self->get_project_handle->get_cgi_dir;
	$object =~ s/\./\//g;
	$object =~ s![^\/]*!$project!;	
	
	# check if this is a CGI
	if ( -f "$cgi_dir/$object.cgi" ) {
		return $self->get_project_handle->get_cgi_url."/$object.cgi";
	}
	
	# Ok, must be a static document
	my $doc_dir   = $self->get_project_handle->get_doc_dir;
	my @filenames = glob "$doc_dir/$object.*";
	
	# is this ambiguous or no files found?
	if ( scalar @filenames == 0 ) {
		die "$throw\tUnable to resolve object '$name'";

	} elsif ( scalar @filenames > 1 ) {
		die "$throw\tObject identifier '$name' is ambiguous";
	}

	# ok, we found exactly one file
	my $file = $filenames[0];
	$file =~ s!^$doc_dir/!!;

	return $self->get_project_handle->get_doc_url."/$file";
}


1;
