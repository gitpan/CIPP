# $Id: Request.pm,v 1.17 2003/08/07 08:08:46 joern Exp $

package CIPP::Runtime::Request;

$VERSION = "0.01";

use strict;
use Carp;
use FileHandle;
use File::Basename;

use vars qw ( %INCLUDE_SUBS %INCLUDE_SUBS_LOADED );

my $DEBUG = -f "/tmp/cipp.debug.enable";

# this hash takes anonymous code references to loaded
# include subroutines ( name => code reference )
%INCLUDE_SUBS = ();

# this hash stores the point of time loading a sub
# ( name => timestamp )
%INCLUDE_SUBS_LOADED = ();

# The program name is initialized when the request object is created

sub get_program_name		{ shift->{program_name}			}

# These values are originally stored in the project_handle
# but copied to the request object for performance reasons.

sub get_cgi_url			{ shift->{cgi_url}			}
sub get_doc_url			{ shift->{doc_url}			}
sub get_prod_dir		{ shift->{prod_dir}			}
sub get_config_dir		{ shift->{config_dir}			}
sub get_inc_dir			{ shift->{inc_dir}			}
sub get_lib_dir			{ shift->{lib_dir}			}
sub get_log_dir			{ shift->{log_dir}			}
sub get_log_file		{ shift->{log_file}			}
sub get_utf8			{ shift->{utf8}				}

# These are accessors for some seldom used project attributes
# (so we don't need to export the Project's interface and can
#  hide all this behind the Request's interface)

sub get_url_par_delimiter	{ shift->get_project_handle->get_url_par_delimiter	}
sub get_add_lib_dirs		{ shift->get_project_handle->get_add_lib_dirs		}
sub get_add_prod_dirs		{ shift->get_project_handle->get_add_prod_dirs		}
sub get_cipp_compiler_version	{ shift->get_project_handle->get_cipp_compiler_version	}
sub get_request_cnt		{ shift->get_project_handle->get_request_cnt		}

sub get_project_handle		{ shift->{project_handle}		}

# public runtime attribues (with read/write access)

sub get_show_error		{ shift->{show_error}			}
sub get_show_error_text		{ shift->{show_error_text}		}

sub set_show_error		{ shift->{show_error}		= $_[1]	}
sub set_show_error_text		{ shift->{show_error_text}	= $_[1]	}

# private runtime attribues (with read/write access)

sub get_cgi_object		{ shift->{cgi_object}			}
sub get_http_header_printed	{ shift->{http_header_printed}		}
sub get_throw			{ shift->{throw}			}
sub get_caller_stack		{ shift->{caller_stack}			}
sub get_profiling_stack		{ shift->{profiling_stack}		}
sub get_profiling_active	{ shift->{profiling_active}		}
sub get_switchdb_stack		{ shift->{switchdb_stack}		}

sub set_cgi_object		{ shift->{cgi_object}		= $_[1]	}
sub set_http_header_printed	{ shift->{http_header_printed}	= $_[1]	}
sub set_throw			{ shift->{throw}		= $_[1]	}
sub set_caller_stack		{ shift->{caller_stack}		= $_[1]	}
sub set_profiling_stack		{ shift->{profiling_stack}	= $_[1]	}
sub set_profiling_active	{ shift->{profiling_active}	= $_[1]	}
sub set_switchdb_stack		{ shift->{switchdb_stack}	= $_[1]	}

# The HTTP header is initialized from the project's default
# HTTP header for each request.

sub get_http_header		{ shift->{http_header}			}

# This is the official method for accessing the $CIPP::request object

sub CIPP::request 		{ $CIPP::request 			}

# This class method controls if runtime errors should be thrown
# as an exception. Default is just printing the error information
# and exit the program normally.

{
	my $throw_runtime_error;
	sub get_throw_runtime_error { $throw_runtime_error		}
	sub set_throw_runtime_error { $throw_runtime_error 	= $_[1] }
}

sub new {
	my $type = shift;
	my %par = @_;
	my  ($project_handle, $program_name) =
	@par{'project_handle','program_name'};

	require CGI;

	my %http_header = %{$project_handle->get_http_header};

	my $self = bless {
		project_handle      => $project_handle,
		program_name        => $program_name,
		cgi_object          => CGI->new,
		dbh	            => {},
		http_header         => \%http_header,
		http_header_printed => 0,
		prod_dir            => $project_handle->get_prod_dir,
		config_dir          => $project_handle->get_config_dir,
		lib_dir             => $project_handle->get_lib_dir,
		log_dir             => $project_handle->get_log_dir,
		inc_dir             => $project_handle->get_inc_dir,
		log_file            => $project_handle->get_log_file,
		cgi_url             => $project_handle->get_cgi_url."/".
				       $project_handle->get_project,
		doc_url             => $project_handle->get_doc_url."/".
				       $project_handle->get_project,
		show_error	    => $project_handle->get_error_show,
		show_error_text	    => $project_handle->get_error_text,
		utf8		    => $project_handle->get_utf8,
		caller_stack	    => [],
		profiling_stack     => [],
		switchdb_stack	    => [],
	}, $type;
	
	return $self;
}

sub debug {
	return if not $DEBUG;
	shift;
	require File::Basename;
	open (DEBUG,">>/tmp/cipp.debug.log") or return;
	print DEBUG scalar(localtime(time)), " $$ '",File::Basename::basename($0),"'\t", join (" ", @_), "\n";
	close DEBUG;
	1;
}

sub init {
	# should be defined by subclasses
}

sub read_input_parameter {
	my $self = shift;
	my %par = @_;
	my ($mandatory, $optional) = @par{'mandatory','optional'};

	my $q = $self->get_cgi_object;

	my ($name, $ref, @missing);

	while ( ($name, $ref) = each %{$mandatory} ) {
		if ( not defined $q->param($name) ) {
			push @missing, $name;
			next;
		}

		if ( ref $ref eq 'SCALAR' ) {
			${$ref} = $q->param($name);
			Encode::_utf8_on(${$ref}) if $self->get_utf8;
		} elsif ( ref $ref eq 'HASH' )  {
			%{$ref} = $q->param($name);
			if ( $self->get_utf8 ) {
				my ($k,$v);
				while ( ($k, $v) = each %{$ref} ) {
					Encode::_utf8_on($k);
					Encode::_utf8_on($v);
				}
			}
		} elsif ( ref $ref eq 'ARRAY' ) {
			@{$ref} = $q->param($name);
			if ( $self->get_utf8 ) {
				foreach my $v ( @{$ref} ) {
					Encode::_utf8_on($v);
				}
			}
		}
	}
	
	croak "Missing input parameters: ".join (", ", @missing) if @missing;
	
	while ( ($name, $ref) = each %{$optional} ) {
		if ( ref $ref eq 'SCALAR' ) {
			${$ref} = $q->param($name);
			Encode::_utf8_on(${$ref}) if $self->get_utf8;
		} elsif ( ref $ref eq 'HASH' )  {
			%{$ref} = $q->param($name);
			if ( $self->get_utf8 ) {
				my ($k,$v);
				while ( ($k, $v) = each %{$ref} ) {
					Encode::_utf8_on($k);
					Encode::_utf8_on($v);
				}
			}
		} elsif ( ref $ref eq 'ARRAY' ) {
			@{$ref} = $q->param($name);
			if ( $self->get_utf8 ) {
				foreach my $v ( @{$ref} ) {
					Encode::_utf8_on($v);
				}
			}
		}
	}
	
	1;
}

sub param {
	my $self = shift;

	if ( $self->get_utf8 ) {
		my $name = shift;
		if ( defined $name ) {
			# requesting the value of $name
			my $value = $self->get_cgi_object->param ( $name );
			Encode::_utf8_on($value);
			return $value;
		} else {
			# requesting list of param names
			my @names = $self->get_cgi_object->param();
			Encode::_utf8_on($_) for @names;
			return @names;
		}
			
	} else {
		# requesting the value of a parameter
		return $self->get_cgi_object->param($_[0]) if @_ == 1;
		# requesting list of parameter names
		return $self->get_cgi_object->param()      if @_ == 0;
	}
}

sub read_config {
	my $self = shift;
	my %par = @_;
	my ($name, $throw) = @par{'name','throw'};
	
	my $filename = $self->resolve_filename (
		name  => $name,
		throw => $throw,
		type  => 'cipp-config',
	);
	
	do $filename;
	
	croak $self->stripped_exception ( throw => $throw ) if $@;
	
	1;
}	

sub stripped_exception {
	my $self = shift;
	my %par = @_;
	my ($msg, $throw) = @par{'msg', 'throw'};
	
	$msg ||= $@;
	$msg =~ s/\s+at\s+[^\s]+\s+line\s+\d+//;
	
	
	return "$throw\t$msg";
}


sub error {
	my $self = shift;
	my %par = @_;
	my  ($message, $cipp_line_nr, $object) =
	@par{'message','cipp_line_nr','object'};

	# extract CIPP exception identifier, if present
	my $throw;
	if ( $message =~ /^(\w+)\t(.*)/s ) {
		$throw   = $1;
		$message = $2;
	}

	# determine perl line number from the exception's message
	my $perl_line_nr;
	if ( $message =~ /\s+at\s+[^\s]+\s+line\s+(\d+)/ ) {
		# program level
		$perl_line_nr = $1;
	}
	if ( $message =~ /\s+at\s+\(eval.*?\)\s+line\s+(\d+)/ ) {
		# eval level (include)
		$perl_line_nr ||= $1;
	}

	# If we have something on the caller stack, determine the
	# latest include called: it's the one, which threw the
	# exception resp. the latest one which must appear
	# in the backtrace (if we have an exception in a module's
	# method)

	my $caller_stack = $self->get_caller_stack;

	if ( @{$caller_stack}  ) {
		my $filename = $caller_stack->[@{$caller_stack}-1]->[3];
		$object = $self->get_include_name ( filename => $filename );
		# the CIPP line can only be determined by reading
		# the include file
		my $full_path = $self->get_inc_dir."/".$filename;
		my $fh = FileHandle->new;
		if ( open ($fh, $full_path) ) {
			my $i = 0;
			while (<$fh>) {
				if ( /^\$_cipp_line_nr=(\d+)/ ) {
					$cipp_line_nr = $1;
				}
				++$i;
				last if $perl_line_nr == $i;
			}
			close $fh;
		} else {
			$cipp_line_nr = "unknown";
		}
	}

	# print a HTTP header, if not yet printed
	if ( not $self->get_http_header_printed ) {
		print "content-type: text/html\n\n";
	}

	# open scripts or tables may confuse some browser,
	# but we *want* our message to appear!
	print "</script></table></table></table></table>".
	      "</table></table></table></table>\n";

	# this is the custom error text
	my $error_text = $self->get_show_error_text ||
		"A runtime exception was thrown.";

	# Check $self->get_show_error only if called in CGI
	# environment, not when executed in the shell.
	
	if ( defined $ENV{QUERY_STRING} and not $self->get_show_error ) {
		print "<p><b>$error_text</b></p>\n";
		return;
	}

	#-------------------------------------------------------------
	# We must distinguish two runtime exception types:
	#
	# 1. exception was thrown from an Include or CIPP Program
	#    => we have exact information of where the exception
	#       was thrown. $cipp_line_nr/$object contain the current CIPP
	#	line nr / object and $self->call_trace has exact
	#	backtracing information. The actual Perl line number
	#	can be taken from $message.
	#
	# 2. exception was thrown from a module
	#    => $cipp_line_nr/$object contains the CIPP program line and
	#       name which called the module's method throwing the
	#       exception.
	#    => $message shows the module name and Perl program line
	#    => we have no correspondent CIPP line of the module
	#	source code available
	#    => so what to do:
	#       - add $line/$object to the call backtrace
	#	- set $line to undef
	#	- extract package from module filename and
	#         set $object to it
	#	- extract $perl_line from error message
	#-------------------------------------------------------------

	my $object_type;

	if ( $message =~ /^.*\s+at\s+(.*?\.pm)\s+line\s+(\d+)/ ) {
		# a module exception
		$object_type = "Module";

		# add caller to stack
		push @{$self->get_caller_stack}, [ $object, $cipp_line_nr, "unknown", "unknown" ];

		# extract information from $message
		my $module_path = $1;
		$perl_line_nr   = $2;
		$cipp_line_nr   = undef;

		# determine module name (grep it's source for 'package')
		# and the CIPP line number (if it's a CIPP module)
		$object = undef;
		my $fh = FileHandle->new;
		if ( open ($fh, $module_path) ) {
			my $i = 0;
			while ( <$fh> ) {
				if ( /package\s+([^\s;]+)/ ) {
					$object = $1;
				}
				if ( /^\$_cipp_line_nr=(\d+)/ ) {
					$cipp_line_nr = $1;
				}
				++$i;
				last if $perl_line_nr == $i;
			}
			close $fh;
		}
		$object ||= "unknown";
	} else {
		$object_type = "Object";
	}

	# strip off "at ..." stuff from the message
	$message =~ s/\s+at\s+[^\s]+\s+line\s+(\d+)//;
	$message =~ s/\s+at\s+\(eval.*?\)\s+line\s+(\d+)//;

	# default values
	$cipp_line_nr ||= "unknown";
	$throw        ||= "generic";
	$object       ||= "unknown";
	$perl_line_nr ||= "unknown";

	# CIPP line nr is unexact, so add >= to it
	$cipp_line_nr = "&gt;= $cipp_line_nr" if $cipp_line_nr ne "unknown";

	# print table with exception information
	my $font = qq{<font face="Courier" color="black" size="2">};
	my $html;
	my $tmpl = <<__HTML;
<p>
<table border="1" cellpadding="4" bgcolor="white">
<tr><td colspan="4" bgcolor="#eeeeee"><b><tt>$error_text</tt></b></td></tr>
<tr><td valign="top">$font<b>$object_type</b></font></td><td colspan="3">$font%s</font></td></tr>
<tr><td valign="top">$font<b>CIPP&nbsp;line&nbsp;</b></font></td><td colspan="3">$font%s</font></td></tr>
<tr><td valign="top">$font<b>Perl&nbsp;line&nbsp;</b></font></td><td colspan="3">$font%s</font></td></tr>
<tr><td valign="top">$font<b>Exception</b></font></td><td colspan="3">$font%s</font></td></tr>
<tr><td valign="top">$font<b>Message</b></font></td><td colspan="3">$font%s</font></td></tr>
__HTML

	$html = sprintf ($tmpl,$object,$cipp_line_nr,$perl_line_nr,$throw,$message);

	# print caller stack, if not a 1st level exception
	my $backtrace;
	if ( @{$self->get_caller_stack} ) {
		my $rowspan = @{$self->get_caller_stack} + 1;

		$html .= <<__HTML;
<tr><td rowspan="$rowspan" valign="top">$font<b>Backtrace</b></font></td>
    <td>$font<b>Caller object</b></font></td>
    <td>$font<b>CIPP line</b></font></td>
    <td>$font<b>Perl line</b></font></td></tr>
__HTML

		foreach my $call ( reverse @{$self->get_caller_stack} ) {
			pop @{$call};
			$html .= qq{<tr>};
			$html .= qq{<td>$font$_</font>} for @{$call};
			$html .= qq{</tr>\n};
			$backtrace .= "called by $call->[0], CIPP line $call->[1], Perl line $call->[2]\n";
		}
	}

	$html .= "</table></p>\n";
	
	print $html if defined $ENV{QUERY_STRING};

	# print the same information in plain text, using a HTML comment
	# in case of a layout disruption "view source" shows the
	# exception information in a more readable form.
	$tmpl = <<__HTML;
$object_type:    %s
CIPP line: %s
Perl line: %s
Exception: %s
Message:
%s
Backtrace:
%s
__HTML

	$cipp_line_nr =~ s/&gt;= //;

	my $msg = sprintf ($tmpl,$object,$cipp_line_nr,$perl_line_nr,$throw,$message,$backtrace);

	print "\n<!--\n\n$msg-->\n";

	die "$throw\t$message" if $self->get_throw_runtime_error;

	$self->log (
		type    => $throw,
		message => "\n$msg",
	);

	1;
}

sub log {
	my $self = shift;
	my %par = @_;
	my  ($type, $message, $filename, $throw) =
	@par{'type','message','filename','throw'};

	$throw ||= "log";
	
	my $time = scalar (localtime);

	my $program = $self->get_program_name;

	my $msg = "$$\t$main::ENV{REMOTE_ADDR}\t$program\t$type\t$message";
	
	my $log_error;
	if ( $filename ne '' ) {
		# a relative path is interpreted relative to project log dir
		if ( $filename !~ m!^/! ) {
			$filename = $self->get_project_handle->get_log_dir."/$filename";
		}
		
	} else {
		$filename = $self->get_project_handle->get_log_file;
	}

	my $dir = dirname($filename);
	mkdir ($dir, 0775) if not -d $dir;

	my $fh = FileHandle->new;
	
	if ( open ($fh, ">> $filename") ) {
		if ( ! print $fh "$time\t$msg\n" ) {
			$log_error = "Can't write data to '$filename'";
		}
		close $fh;
	} else {
		$log_error = "Can't open file '$filename' for writing.";
	}
	
	croak "$throw\t$log_error" if $log_error;
	
	1;
}

sub init_error {
	my $self = shift;
	my %par = @_;
	my ($message) = @par{'message'};
	
	if ( not $self->get_http_header_printed ) {
		print "content-type: text/html\n\n";
	}

	print "Initialization Error\n";
	
	$self->exit;

	1;
}

sub exit {
	my $self = shift;
	die "_cipp_exit_command";
}

sub html_quote {
	shift;
        my ($text) = @_;

        $text =~ s/&/&amp;/g;
        $text =~ s/</&lt;/g;
        $text =~ s/\"/&quot;/g;

        return $text;
}

sub html_field_quote {
	shift;
        my ($text) = @_;

	$text =~ s/&/&amp;/g;
        $text =~ s/\"/&quot;/g;

        return $text;
}

sub url_encode {
	shift;
	my ($text) = @_;
	$text =~ s/(\W)/(ord($1)>15)?(sprintf("%%%x",ord($1))):("%0".sprintf("%lx",ord($1)))/eg;

	return $text;
}

sub fetch_upload {
	my $self = shift;
	my %par = @_;
	my  ($filename, $fh, $throw) =
	@par{'filename','fh','throw'};
	
	$throw ||= "fetchupload";

	my $source_fh = $fh;
	croak "$throw\tForm file upload variable is missing."
		if not defined $source_fh;

	my $target_fh = FileHandle->new;
	open ($target_fh, "> $filename")
		or croak "$throw\tCan't open '$filename' for writing: $!";
	
	binmode $source_fh;
	binmode $target_fh;
	
	my ($buffer, $read_result);
	while ( $read_result = read ($source_fh, $buffer, 1024) ) {
		print $target_fh $buffer
			or croak "$throw\tError writing to the target file: $!";
	}
	
	croak "$throw\tError reading the upload file. ".
	    qq{Did you set enctype="multipart/form-data" ?}
	    	if not defined $read_result;

	close $target_fh;
	
	# This enables subsequent FETCHUPLOADs of the same
	# filehandle, also if the user sends the same file
	# with different file upload fields (the CGI module
	# creates a symbolic filehandle with the name of
	# the uploaded file)
	seek ($fh, 0, 0) or croak "$throw\tcan't seek filehandle";

	1;
}

sub get_object_url {
	croak "not implemented";
}

sub dbh {
	my $self = shift;
	my ($name) = @_;

	return $self->{dbh}->{$name} if defined $self->{dbh}->{$name};
	
	eval "use DBI 1.30";
	croak $self->stripped_exception ( throw => "sql_open" ) if $@;

	my $config = $self->get_db_config ( db => $name );

	my $dbh;
	eval {
		$dbh = DBI->connect (
			$config->{data_source},
			$config->{user},
			$config->{password},
			{
				PrintError => 0,
				RaiseError => 1,
				ShowErrorStatement => 1,
				AutoCommit => $config->{autocommit},
				HandleError => sub {
					croak($CIPP::request->get_throw."\t".shift);
				},
			}
		);
	};
	
	croak $self->stripped_exception ( throw => "sql_open" ) if $@;

	$dbh->do ( $config->{init} ) if $config->{init};
	
	$self->{dbh}->{$name} = $dbh;
	
	return $dbh;
}

sub switch_db {
	my $self = shift;
	my %par = @_;
	my ($dbh) = @par{'dbh'};

	push @{$self->get_switchdb_stack}, $self->{dbh}->{default};
	
	$self->{dbh}->{default} = $dbh;

	1;
}

sub unswitch_db {
	my $self = shift;
	
	$self->{dbh}->{default} = pop @{$self->get_switchdb_stack};
	
	1;
}

{
	my @sql_profiling;
	
	use constant DBH     => 0;
	use constant SQL     => 1;
	use constant PARAMS  => 2;
	use constant THROW   => 3;
	use constant PROFILE => 4;

	sub sql_select {
		my $self = shift;

		if ( $self->{utf8} ) {
			utf8::upgrade($_[SQL]);
			utf8::upgrade($_) for @{$_[PARAMS]};
		}

		if  ( $self->{profiling_active} ) {
			push @sql_profiling, {
				time => Time::HiRes::time(),
				sql  => $_[SQL],
			};

			$self->print_command_duration (
				command => $_[PROFILE],
				detail  => $_[SQL],
				force   => 1,
			);
		}

		my $sth = $_[DBH]->prepare ($_[SQL]);
		$sth->execute (@{$_[PARAMS]});

		return $sth;
	}

	sub sql_select_finished {
		my $self = shift;
		return if not $self->{profiling_active};

		my $end_time = Time::HiRes::time();
		my $data = pop @sql_profiling;
		
		$self->print_command_duration (
			command => "sql out",
			detail  => $data->{sql},
			time    => $end_time - $data->{time},
		);
		
		1;
	}
}

sub sql_do {
	my $self = shift;
	my ($dbh, $sql, $params, $throw, $profile) = @_;
	
	my $start_time = Time::HiRes::time() if $self->get_profiling_active;

	if ( $self->{utf8} ) {
		utf8::upgrade($sql);
		utf8::upgrade($_) for @{$params};
	}

	for ( @{$params} ) { $_ = undef if $_ eq '' };

	my $rc = $dbh->do ($sql, {}, @{$params});

	if ( $self->{profiling_active} ) {
		$self->print_command_duration (
			command => $profile,
			detail  => $sql,
			time    => Time::HiRes::time() - $start_time,
		);
	}
	
	return $rc * 1;
}

sub close {
	my $self = shift;
	foreach my $dbh ( values %{$self->{dbh}} ) {
		$dbh->rollback if not $dbh->{AutoCommit};
		$dbh->disconnect;
	}

	$self->{dbh} = {};

	$CIPP::request = undef;

	1;
}

sub add_include_subroutine {
	my $class = shift;
	my %par = @_;
	my ($file, $code) = @par{'file','code'};

	$INCLUDE_SUBS{$file} = $code;

	1;
}

sub call_include_subroutine {
	my $self = shift;
	my %par = @_;
	my  ($file, $input, $output, $caller, $cipp_line_nr) =
	@par{'file','input','output','caller','cipp_line_nr'};

	# profiling start
	my $start_time;
	my $old_profiling_active = 0;
	if ( $self->get_profiling_active ) {
		$old_profiling_active = 1;
		$self->set_profiling_active(0)
			if not $self->get_profiling_stack
				    ->[@{$self->get_profiling_stack}-1]
				    ->{deep};
		$self->print_command_duration (
			command => "inc in",
			detail  => $file,
			time    => "",
			force   => 1,
		);
		$start_time = Time::HiRes::time();
	}

	# trace include calls
	my $perl_line_nr = (caller(0))[2];
	push @{$self->get_caller_stack}, [ $caller, $cipp_line_nr, $perl_line_nr, $file ];

	# load the subroutine
	my $sub = $self->load_include_subroutine ($file);

	# collect stat data, if configuried
	$self->{stat} && $self->{stat}->log ("execute_include_start", $file);
	
	# excecute the subroutine
	my $output_href = &$sub ($input);

	# collect stat data, if configuried
	$self->{stat} && $self->{stat}->log ("execute_include_end", $file);

	# return output parameters
	foreach my $name ( keys %{$output} ) {
		if ( ref $output_href->{$name} eq 'SCALAR' or
		     ref $output_href->{$name} eq 'REF' ) {
			${$output->{$name}} = ${$output_href->{$name}};
		} elsif ( ref $output_href->{$name} eq 'ARRAY' ) {
			@{$output->{$name}} = @{$output_href->{$name}};
		} elsif ( ref $output_href->{$name} eq 'HASH' ) {
			%{$output->{$name}} = %{$output_href->{$name}};
		} else {
			croak "INCLUDE\tunknown output parameter type: $name: ".
			    ref($output_href->{$name});
		}
	}

	# restore profile flag
	$self->set_profiling_active($old_profiling_active);

	# remove this call from caller stack
	pop @{$self->get_caller_stack};

	# profiling: print command duration
	if ( $self->get_profiling_active ) {
		$self->print_command_duration (
			command => "inc out",
			detail  => $file,
			time    => Time::HiRes::time() - $start_time,
		);
	}

	1;
}

sub resolve_inc_filename {
	my $self = shift;
	my %par = @_;
	my ($file) = @par{'file'};

	my $inc_dir   = $self->get_inc_dir;
	my $full_path = "$inc_dir/$file";

	if ( not -e $full_path ) {
		foreach my $inc_dir ( map   { $_."/inc" }
				      @{$self->get_add_prod_dirs} ) {
			$full_path = "$inc_dir/$file";
			last if -e $full_path;
		}

		# set full_path to this project's inc_dir, if not
		# found. This produces an error message in load_include_subroutine
		# containing the path belonging to this project.
		$full_path = "$inc_dir/".$file if not -e $full_path;
	}

	return $full_path;
}

sub load_include_subroutine {
	my $self = shift;
	my ($file) = @_;

	# no need to check or do anything if already loaded during this request
	# (changes made during one request are silently ignored)
	return $INCLUDE_SUBS{$file}
		if exists $self->{loaded_subroutines}->{$file};
	
	# search absolute filename for this subroutine
	# (search in inc_dir and additional projects)
	my $full_path = $self->resolve_inc_filename ( file => $file );

	# track start time if profiling is active
	my $start_time;
	$start_time = Time::HiRes::time() if $self->get_profiling_active;
	
	# filename of subroutine
	my $perl_code_file = $full_path;
	
	# subroutine already loaded and up to date?
	# then we can return the sub reference immediately
	if ( defined $INCLUDE_SUBS{$file} ) {
		my $load_time = $INCLUDE_SUBS_LOADED{$file};
		my $mtime = (stat($perl_code_file))[9];
		return $INCLUDE_SUBS{$file} if $mtime < $load_time;
	}
	
	# otherwise load the subroutine perl code file
	open (PC, $perl_code_file) or croak "INCLUDE\tcan't read $perl_code_file";
	my $perl_code;
	$perl_code .= $_ while <PC>;
	close PC;
	
	# evalulate the code
	my $sub = eval_perl_code (\$perl_code);
	
	croak $self->stripped_exception (
		msg   => "Runtime error loading include file '$perl_code_file':\n$@",
		throw => "INCLUDE"
	) if $@ or not ref $sub;

	# store load time in global hash
	$INCLUDE_SUBS_LOADED{$file} = time;

	# store subroutine in global hash
	$INCLUDE_SUBS{$file} = $sub;
	
	# ok, subsequent include subroutine calls can call the subroutine
	# immediately, without the whole load and cache check stuff
	$self->{loaded_subroutines}->{$file} = 1;

	if ( 0 and $self->get_profiling_active ) {
		$self->print_command_duration (
			command => "load_inc",
			detail  => basename($full_path),
			time    => Time::HiRes::time() - $start_time,
		);
	}

	return $sub;
}

sub start_profiling {
	my $self = shift;
	my %par = @_;
	my  ($name, $deep, $filename, $filter, $scale_unit) =
	@par{'name','deep','filename','filter','scale_unit'};

	require Time::HiRes;

	$filename ||= $self->get_log_dir."/profile.log";

	my $open_mode;
	if ( -s $filename > 8589934592 ) {
		# remove profile file if size exceeds 8 MB
		$open_mode = ">";
	} else {
		$open_mode = ">>";
	}

	my $fh = FileHandle->new;
	open ($fh, "$open_mode $filename")
		or croak "profile\tCan't write $filename";
	select $fh;
	$| = 1;
	select STDOUT;

	print $fh "*******   File exceeded 8 MB and was truncated.\n"
		if $open_mode eq '>';

	push @{$self->get_profiling_stack}, {
		name        => $name,
		deep        => $deep,
		time        => Time::HiRes::time(),
		fh          => $fh,
		filter      => $filter,
		scale_unit  => $scale_unit,
	};

	$self->set_profiling_active ( 1 );

	$deep = $deep ? "DEEP " : "";
	$deep .= "-" x (60 - length($deep));
	

	printf $fh "\nPROFILE %5d %-10s %-10s %-60s\n",
		   $$, $name, "START", $deep;

	1;
}

sub stop_profiling {
	my $self = shift;
	
	my $data = pop @{$self->get_profiling_stack};
	my $time = Time::HiRes::time() - $data->{time};
	
	my $fh = $data->{fh};
	
	my $summary = "SUMMARY ".("=" x 52);
	
	$time = $self->get_profile_time ( time => $time, profile => $data );

	printf $fh "PROFILE %5d %-10s %-10s %-60s    %s\n\n",
	       $$, $data->{name}, "END", $summary, $time;

	$self->set_profiling_active ( 0 )
		if not @{$self->get_profiling_stack};

	close $fh;

	1;
}

sub print_command_duration {
	my $self = shift;
	my %par = @_;
	my  ($time, $command, $detail, $force) =
	@par{'time','command','detail','force'};

	my $data = $self->get_profiling_stack
			->[@{$self->get_profiling_stack}-1];

	return 1 if not $force and $time < $data->{filter};

	my $levels = "+" x (@{$self->get_caller_stack}+1);

	$detail =~ s/\s+/ /g;
	$detail = "$levels $detail";
	$detail = substr($detail.(" "x 60),0,60);

	$detail =~ s/(\s+)$/" ".("." x (length($1)-1))/e if $time;

	$time  = $self->get_profile_time ( time => $time, profile => $data );

	my $fh = $data->{fh};

	printf $fh "PROFILE %5d %-10s %-10s %-60s    %s\n",
	       $$, $data->{name}, $command, $detail, $time;

	1;	
}

sub get_profile_time {
	my $self = shift;
	my %par = @_;
	my ($time, $profile) = @par{'time','profile'};
	
	return "" if $time == 0;
	
	my $formatted = sprintf ("%2.4f ", $time);
	
	$formatted .= "o" x int($time / $profile->{scale_unit});
	
	return $formatted;
}

sub eval_perl_code {
	# do the eval in this mini subroutine, so NO lexicals
	# are in the scope of it.
	# checking of $@ has to be done by the caller
	eval ${$_[0]};
}

sub print_http_header {
	my $self = shift;
	my %par = @_;
	my ($custom_http_header_file) = @par{'custom_http_header_file'};

	# evtl. execute custom http header subroutine
	$self->call_include_subroutine (
		file   => $custom_http_header_file,
		input  => {},
		output => {},
	) if $custom_http_header_file;

	# print HTTP Header
	my ($k, $v);
	my $content_type;
	while ( ($k, $v) = each %{$self->get_http_header} ) {
#		$k =~ s/\b([a-z])/uc($1)/eg;
		print "$k: $v\n";
		$content_type = $v if $k =~ /^content-type$/i;
	}
	
	print "\n";
	
	$self->set_http_header_printed (1);

	if ( $content_type eq 'text/html' ) {
		my $runtime  = $CIPP::Runtime::Request::VERSION;
		my $compiler = $self->get_project_handle->get_cipp_compiler_version;
		print "<!-- Generated with CIPP, compiler version: $compiler, runtime version: $runtime -->\n";
		print "<!-- CIPP - Copyright (c) dimedis GmbH, All Rights Reserved -->\n\n";
	}

	1;
}	

sub load_module {
	my $self = shift;
	my %par = @_;
	my ($name) = @par{'name'};
	
	$name =~ s!::!/!og;
	$name .= ".pm";

	require $name;

	1;
}

1;

__END__

=head1 NAME

CIPP::Request - CIPP runtime environment interface

=head1 SYNOPSIS

  use CIPP::Request;

  # The request object is always accessed through this class method
  # (Object creation is done magically by the runtime
  #  environment: new.spirit, Apache or whatever...)
  $request = CIPP->request;

  # Get the current CGI object for this request
  $cgi_object		 = CIPP->request->get_cgi_object;

  # Several static configuation information is accessable
  # through this object
  $cgi_url               = CIPP->request->get_cgi_url;
  $doc_url               = CIPP->request->get_doc_url;
  $prod_dir              = CIPP->request->get_prod_dir;
  $config_dir            = CIPP->request->get_config_dir;
  $inc_dir               = CIPP->request->get_inc_dir;
  $lib_dir               = CIPP->request->get_lib_dir;
  $log_dir               = CIPP->request->get_log_dir;
  $log_file              = CIPP->request->get_log_file;
  $url_par_delimiter     = CIPP->request->get_url_par_delimiter;
  $add_lib_dirs          = CIPP->request->get_add_lib_dirs;
  $show_error            = CIPP->request->get_show_error;
  $error_text            = CIPP->request->get_show_error_text;
  $cipp_compiler_version = CIPP->request->get_cipp_compiler_version;

  # get the current request counter of this process
  $request_cnt           = CIPP->request->get_request_cnt;
	
  # was the HTTP header already printed for this request?
  $http_header_printed	 = CIPP->request->get_http_header_printed;

  # control error message output for this request
  CIPP->request->set_show_error ( $bool );
  CIPP->request->set_show_error_text ( $message );

=head1 DESCRIPTION

This module represents the interface to the CIPP runtime environment.

=head1 AUTOR

Joern Reder <joern@dimedis.de>

=head1 COPYRIGHT

Copyright (c) 2001-2002 dimedis GmbH, All Rights Reserved

=head1 SEE ALSO

CIPP, CIPP::Manual, new.spirit

=cut

