# $Id: NewSpirit.pm,v 1.16 2003/08/07 08:06:06 joern Exp $

package CIPP::Compile::NewSpirit;

@ISA = qw ( CIPP::Compile::Generator );

use strict;
use Carp;
use FileHandle;
use File::Basename;
use CIPP::Compile::Generator;

sub new {
	my $type = shift;
	my %par = @_;
	my  ($shebang, $project_root, $mime_type) =
	@par{'shebang','project_root','mime_type'};

	confess "Please specify the following parameters:\n".
	      "project_root\n".
	      "Got: ".join(', ', keys(%par))."\n"
	      	unless $project_root;
	
	my $self = bless $type->SUPER::new(@_), $type;

	my $back_prod_path = $self->get_program_name;
	$back_prod_path =~ s!\.!/!g;
	$back_prod_path =~ s![^/]+!..!g;

	$self->set_gen_ns_shebang ($shebang);
	$self->set_gen_ns_project_root ($project_root);
	$self->set_gen_ns_back_prod_path ($back_prod_path);

	$self->get_state->{autoprint} = 1 if $mime_type ne 'cipp/dynamic';

	my $program_name = $self->get_program_name;
	$program_name =~ s/^[^.]+/$self->get_project/e;
	$self->{program_name} = $program_name;

	( $self->{in_filename}, $self->{out_filename},
	  $self->{prod_filename}, $self->{dep_filename},
	  $self->{iface_filename}, $self->{err_filename},
	  $self->{http_filename} )
	  	= $self->get_object_filenames;

	$self->set_err_copy_filename ($self->get_out_filename.".err");

	# cipp-html objects always depend on the base configuration
	if ( $self->get_object_type eq 'cipp-html' ) {
		$self->add_used_object (
			name => "x.configuration",
			ext  => "cipp-base-config",
			type => "cipp-base-conf",
		);
		$self->set_dont_cache (1);
	}

	return $self;
}

sub get_gen_ns_shebang		{ shift->{gen_ns_shebang}		}
sub get_gen_ns_back_prod_path	{ shift->{gen_ns_back_prod_path}	}
sub get_gen_ns_project_root	{ shift->{gen_ns_project_root}		}

sub set_gen_ns_shebang		{ shift->{gen_ns_shebang}	= $_[1]	}
sub set_gen_ns_back_prod_path	{ shift->{gen_ns_back_prod_path}= $_[1]	}
sub set_gen_ns_project_root	{ shift->{gen_ns_project_root}	= $_[1]	}

#---------------------------------------------------------------------
# This interface must be implemented by the Generator/* modules
#---------------------------------------------------------------------

sub create_new_parser {
	my $self = shift; $self->trace_in;
	my %par = @_;
	my  ($object_type, $program_name, $in_filename, $in_fh) =
	@par{'object_type','program_name','in_filename','in_fh'};
	
	my $parser = (ref $self)->new (
		object_type   => $object_type,
		program_name  => $program_name,
		in_filename   => $in_filename,
		in_fh 	      => $in_fh,
		project       => $self->get_project,
		start_context => $self->get_start_context,	# ??? not actual context?
		shebang       => $self->get_gen_ns_shebang,
		project_root  => $self->get_gen_ns_project_root,
	);

	$parser->set_inc_trace (
		$self->get_inc_trace.$self->get_normalized_object_name (
			name => $program_name
		).":"
	);
	
	return $parser;
}

sub generate_start_program {
	my $self = shift; $self->trace_in;

	$self->write($self->get_gen_ns_shebang, "\n\n");
	$self->write ("use strict;\n\n");
	$self->write ("package main;\n\n");
	$self->write ('my ($_cipp_project, $_cipp_line_nr);'."\n\n");

	1;
}

sub generate_project_handler {
	my $self = shift; $self->trace_in;
	
	$self->writef (<<'__EOC'
use CIPP::Runtime::NewSpirit;

# This BEGIN block is executed once under mod_perl.
# (and will not be filtered for syntax check in
#  new.spirit, which is indicated by the {# below)

BEGIN {#
    # initialize this process for this project
    # (multi initializing per process/project is
    #  prevented by the init method)
    CIPP::Runtime::NewSpirit::Project->init (
	project        => "%s",
	back_prod_path => "%s",
    );
}

$_cipp_project = CIPP::Runtime::NewSpirit::Project->handle (
    project => "%s",
);

__EOC
		, $self->get_project,
		  $self->get_gen_ns_back_prod_path,
		  $self->get_project,
	);
}

sub generate_open_request {
	my $self = shift; $self->trace_in;
	
	$self->write (
		'$_cipp_project->new_request ('."\n",
		'    program_name => "'.$self->get_program_name.'",'."\n",
		'    mime_type => "'.$self->get_mime_type,'",'."\n",
		');'."\n\n",
	);
	
	if ( not $self->get_no_http_header ) {
		my $http_header_file = $self->custom_http_header_file;
		if ( $http_header_file ) {
			$self->writef (
				'CIPP->request->print_http_header ('."\n".
				'  custom_http_header_file => "%s",'."\n".
				');'."\n",
				$http_header_file
			);
		} else {
			$self->write (
				'CIPP->request->print_http_header;'."\n",
			);
		}
	}

	1;
}

sub get_normalized_object_name {
	my $self = shift; $self->trace_in;
	my %par = @_;
	my ($name) = @par{'name'};
	
	$name =~ s/^[^.]+\.//;
	$name =~ tr!.!/!;
	
	return $name;
}

sub get_object_filename {
	my $self = shift; $self->trace_in;
	my %par = @_;
	my  ($name, $name_is_normalized) =
	@par{'name','name_is_normalized'};

	my $file;
	if ( $name_is_normalized ) {
		$file = $name;
	} else {
		$file = $self->get_normalized_object_name ( name => $name );
	}

	$file = $self->get_gen_ns_project_root."/src/".$file;

	my $dir = dirname $file;
	my $filename = basename $file;

	my $dh = FileHandle->new;
	opendir $dh, $dir or return;
	my @filenames = grep (!/\.m$/, (grep /^$filename\.[^\.]+$/, readdir $dh));
	closedir $dh;
	
	return if scalar @filenames != 1;
	return $dir."/".$filenames[0];
}

sub determine_object_type {
	my $self = shift; $self->trace_in;
	my %par = @_;
	my ($name, $filename) = @par{'name','filename'};

	confess "name *and* filename given" if $name and $filename;

	$filename ||= $self->get_object_filename ( name => $name );
	return if not defined $filename;

	$filename =~ /\.([^\.]+)$/;

	my $ext = $1;
	my $type = $ext;
	
	if ( $ext =~ /^(gif|jpg|jpeg|jpe|png)$/i ) {
		$type = 'cipp-img';
	} elsif ( $ext eq 'ns-unknown' ) {
		$type = 'generic';
	} elsif ( $ext =~ /^(jar|cab|class|properties)$/i ) {
		$type = 'jar';
	} elsif ( $ext =~ /^cipp-/ and
		  $ext !~ /^cipp-(config|db|module|inc|sql)$/ ) {
		$type = 'cipp-html';
	} elsif ( $ext =~ /^(js|css|txt|html)$/ ) {
		$type = 'text'
	}
	
	return $type;
}

sub get_object_url {
	my $self = shift; $self->trace_in;
	my %par = @_;
	my  ($name, $add_message_if_has_no) =
	@par{'name','add_message_if_has_no'};

	my $object_url;
	eval {
		my $filename    = $self->get_object_filename ( name => $name ) or die;
		my $object_type = $self->determine_object_type ( filename => $filename ) or die;

		my $src_dir = $self->get_gen_ns_project_root."/src";
		$filename =~ s!^$src_dir/?!!;
		$filename =~ s!\.([^\.]+)$!!;
		my $ext = $1;

		if ( $object_type eq 'cipp' ) {
			$object_url = '}.CIPP->request->get_cgi_url.qq{/'.$filename.'.cgi';

		} elsif ( $object_type eq 'cipp-html' or $object_type eq 'text' or
		 	  $object_type eq 'jar' ) {
			$ext =~ m!cipp-(.*)$!;
			$object_url = '}.CIPP->request->get_doc_url.qq{/'.$filename.".$1";

		} elsif ( $object_type eq 'cipp-img' or $object_type eq 'blob' ) {
			$object_url = '}.CIPP->request->get_doc_url.qq{/'.$filename.".".$ext;

		} elsif ( $object_type eq 'generic' ) {
			my $meta_file = $self->get_object_filename ( name => $name ).".m";
			die if not -r $meta_file;
			my $meta_data = do $meta_file;
			die if not $meta_data->{install_target_dir};
			$filename =~ s![^/]+$!!;
			my $orig_filename = $meta_data->{_original_filename};
			if ( $meta_data->{install_target_dir} eq 'htdocs' ) {
				$object_url = '}.CIPP->request->get_doc_url.qq{'.
					      $filename.'/'.$orig_filename;
			} else {
				$object_url = '}.CIPP->request->get_cgi_url.qq{'.
					      $filename.'/'.$orig_filename;
			}
			$object_url =~ s!/+!/!g;
		} else {
			confess "unknown object type '$object_type'";
		}
	};

	$self->add_tag_message (
		message => "The object '$name' has no URL."
	) if not $object_url and $add_message_if_has_no;

	return $object_url;
}

sub get_object_filenames {
	my $self = shift; $self->trace_in;
	my %par = @_;
	my  ($norm_name, $object_type) =
	@par{'norm_name','object_type'};

	$norm_name   ||= $self->get_normalized_object_name
				( name => $self->get_program_name );
	$object_type ||= $self->get_object_type;

	my $base_dir = $self->get_gen_ns_project_root;
	my $project  = $self->get_project;

	my ($in_filename, $out_filename, $prod_filename,
	    $dep_filename, $iface_filename, $err_filename,
	    $http_filename);
	
	if ( $object_type eq 'cipp-inc' ) {
		$in_filename	    = "$base_dir/src/$norm_name.cipp-inc";
		$out_filename       = "$base_dir/prod/inc/$norm_name.code";
		$prod_filename      = "$base_dir/prod/inc/$norm_name.code";
		$dep_filename	    = "$base_dir/meta/##cipp_dep/$norm_name.dep";
		$iface_filename     = "$base_dir/meta/##cipp_dep/$norm_name.iface";
		$err_filename       = "$base_dir/meta/##cipp_dep/$norm_name.err";
		$http_filename      = "$base_dir/prod/inc/$norm_name.http";

	} elsif ( $object_type eq 'cipp' ) {
		$in_filename	    = "$base_dir/src/$norm_name.cipp";
		$out_filename       = "$base_dir/prod/cgi-bin/$project/$norm_name.cgi";
		$prod_filename      = "$base_dir/prod/cgi-bin/$project/$norm_name.cgi";
		$dep_filename	    = "$base_dir/meta/##cipp_dep/$norm_name.dep";
		$iface_filename     = "";
		$err_filename       = "$base_dir/meta/##cipp_dep/$norm_name.err";
		$http_filename      = "$base_dir/prod/inc/$norm_name.http";

	} elsif ( $object_type eq 'cipp-html' ) {
		my $src_filename = $self->get_object_filename (
			name => $norm_name,
			name_is_normalized => 1
		);

		confess "can't resolve source filename for object '$norm_name'"
			if not $src_filename;

		$src_filename =~ /cipp-(.*)$/;
		my $ext = $1;
		
		$in_filename	    = "$base_dir/src/$norm_name.cipp-$ext";
		$out_filename       = "/tmp/cipp_html_$$";
		$prod_filename      = "$base_dir/prod/htdocs/$project/$norm_name.$ext";
		$dep_filename	    = "$base_dir/meta/##cipp_dep/$norm_name.dep";
		$iface_filename     = "";
		$err_filename       = "$base_dir/meta/##cipp_dep/$norm_name.err";
		$http_filename      = "";

	} elsif ( $object_type eq 'cipp-module' ) {
		my $module_name = $self->get_module_name;
		$module_name =~ s!::!/!g;
		
		$in_filename	    = "$base_dir/src/$norm_name.cipp-module";
		$out_filename       = "/tmp/cipp_module_$$";
		
		if ( not $module_name ) {
			$prod_filename = "/tmp/cipp_module_$$";
		} else {
			$prod_filename = "$base_dir/prod/lib/$module_name.pm";
		}

		$dep_filename	    = "$base_dir/meta/##cipp_dep/$norm_name.dep";
		$iface_filename     = "";
		$err_filename       = "$base_dir/meta/##cipp_dep/$norm_name.err";
		$http_filename      = "";

	} else {
		confess "unknown object type '$object_type'";
	}

	return ($in_filename,    $out_filename,
		$prod_filename,  $dep_filename,
		$iface_filename, $err_filename,
		$http_filename);
}

sub get_relative_inc_path {
	my $self = shift;
	my %par = @_;
	my ($filename) = @par{'filename'};
	
	my $base_dir = $self->get_gen_ns_project_root;
	
	$filename =~ s!^$base_dir/prod/inc/!!;
	
	return $filename;
}

1;
