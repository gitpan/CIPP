package CIPP::Stat::Show;

use strict;
use FileHandle;
use Apache::Constants ':common';

use vars qw ( $VERSION  );

$VERSION = "0.01";

my $FONT = qq{<font face="Arial,Helvetica,Geneva">};

sub handler {
	my $r = shift;

	$r->content_type ("text/html");
	$r->send_http_header;
	
	my $stat_show = CIPP::Stat::Show->new (
		apache_request => $r
	);
	
	$stat_show->request;

	return OK;
}

sub new {
	my $type = shift;
	
	my %par = @_;
	
	my ($apache_request) = @par{'apache_request'};

	my $cache_dir  = $apache_request->dir_config ("cache_dir");
	my $stat_dir   = "$cache_dir/.stats";
	my $uri        = $apache_request->uri;
	
	my $args = $apache_request->args;
	my %args = $apache_request->args;
	my $uri_w_args = $uri;
	$uri_w_args .= "?$args" if $args;
	
	my $self = {
		apache_request => $apache_request,
		cache_dir => $cache_dir,
		stat_dir => $stat_dir,
		document_root => $apache_request->document_root,
		uri => $uri,
		uri_w_args => $uri_w_args,
		args => \%args,
	};
	
	return bless $self, $type;
}

sub request {
	my $self = shift;
	
	$self->header;
	
	if ( not $self->{apache_request}->dir_config ("stat") ) {
		print "<b>CIPP statistics not enabled in server configuration!</b>\n";
		$self->footer;
		return;
	}
	
	$self->collect_statistics;
	$self->print_statistics;
	
	$self->footer;
	
	1;
}

sub header {
	my $self = shift;

	my $uri = $self->{apache_request}->uri;
	my $args = $self->{apache_request}->args;
	$uri .= "?$args" if $args;
	
	my $refresh =
		qq{<META HTTP-EQUIV="REFRESH" }.
		qq{CONTENT="$self->{args}->{refresh}; URL=$uri">}
			if $self->{args}->{refresh};

	my $refresh_switch;
	if ( $self->{args}->{refresh} ) {
		my $uri = $self->{uri_w_args};
		$uri =~ s/refresh=\d+/refresh=0/;
		$refresh_switch =
			qq{[<a href="$uri">turn auto refresh off</a>]};
	} else {
		my $uri = $self->{uri_w_args};
		$uri =~ s/[&?]refresh=\d+//;
		if ( $uri =~ /\?/ ) {
			$uri .= "&refresh=5";
		} else {
			$uri .= "?refresh=5";
		}
		$refresh_switch =
			qq{[<a href="$uri">turn auto refresh on</a>]};
	}

	print <<__HTML;
$refresh
<html>
<head><title>CIPP server statistics</title></header>
<body bgcolor="white">
$FONT
<big><b>CIPP server statistics</b></big>
$refresh_switch
<hr noshade size="1">
<p>
__HTML
	1;
}

sub footer {
	my $self = shift;
	
	my $ID = q$Id: Show.pm,v 1.1.1.1 2001/03/17 15:44:26 joern Exp $;
	
	print <<__HTML;
<p>
<hr noshade size="1">
<small>$ID, Copyright &copy; 2001 Jörn Reder, Germany</small>
</font>
</body>
</html>
__HTML
	1;
}

sub collect_statistics {
	my $self = shift;
	
	my $stat_dir = $self->{stat_dir};

	my %objects;
	my %includes;

	$self->{data}->{includes} = \%includes;
	$self->{data}->{objects}  = \%objects;
	
	foreach my $file ( <$stat_dir/*> ) {
		# first make hardlink, so if a apache process dies,
		# the corresponding file will not disappear
		link ($file, "$file.work");
		
		$self->process_stat_file ("$file.work");
		unlink "$file.work";
		
		$self->{data}->{processes}++;
	}
	
	1;
}

sub process_stat_file {
	my $self = shift;
	
	my ($file) = @_;
	
	my $objects  = $self->{data}->{objects};
	my $includes = $self->{data}->{includes};
	
	my $cache_dir     = $self->{cache_dir};

	open (IN, $file) or return;
	while (<IN>) {
		chomp;
		my ($time, $object, $action, $file) = split (/\t/, $_);

		if ( $action eq 'request_start' ) {
			# starting a new request
			$objects->{$object}->{name} = $object;
			$objects->{$object}->{exec_cnt}++;

			# store start time
			$objects->{$object}->{exec_start_time} = $time;

		} elsif ( $action eq 'request_end' ) {
			# a request ended
			my $elapsed = $time - $objects->{$object}->{exec_start_time};
			if ( $objects->{$object}->{exec_min} > $elapsed or
			     not defined $objects->{$object}->{exec_min} ) {
				$objects->{$object}->{exec_min} = $elapsed;
			}
			if ( $objects->{$object}->{exec_max} < $elapsed or
			     not defined $objects->{$object}->{exec_max} ) {
				$objects->{$object}->{exec_max} = $elapsed;
			}
			
			$objects->{$object}->{exec_avg} =
				( $objects->{$object}->{exec_avg} * ($objects->{$object}->{exec_cnt}-1)
				  + $elapsed ) / $objects->{$object}->{exec_cnt};

		} elsif ( $action eq 'load_include_start' ) {
			# loading a include
			$includes->{$file}->{load_cnt}++;
			$includes->{$file}->{name} = $file;

			# store start time
			$includes->{$file}->{load_start_time} = $time;

		} elsif ( $action eq 'load_include_end' ) {
			# a request ended
			my $elapsed = $time - $includes->{$file}->{load_start_time};
			if ( $includes->{$file}->{load_min} > $elapsed or
			     not defined $includes->{$file}->{load_min} ) {
				$includes->{$file}->{load_min} = $elapsed;
			}
			if ( $includes->{$file}->{load_max} < $elapsed or
			     not defined $objects->{$object}->{load_max} ) {
				$includes->{$file}->{load_max} = $elapsed;
			}
			
			$includes->{$file}->{load_avg} =
				( $includes->{$file}->{load_avg} * ($includes->{$file}->{load_cnt}-1)
				  + $elapsed ) / $includes->{$file}->{load_cnt};
			
		} elsif ( $action eq 'execute_include_start' ) {
			# loading a include
			$includes->{$file}->{exec_cnt}++;
			$includes->{$file}->{name} = $file;

			# store start time
			$includes->{$file}->{exec_start_time} = $time;

		} elsif ( $action eq 'execute_include_end' ) {
			# a request ended
			my $elapsed = $time - $includes->{$file}->{exec_start_time};
			if ( $includes->{$file}->{exec_min} > $elapsed or
			     not defined $includes->{$file}->{exec_min} ) {
				$includes->{$file}->{exec_min} = $elapsed;
			}
			if ( $includes->{$file}->{exec_max} < $elapsed or
			     not defined $objects->{$object}->{exec_max} ) {
				$includes->{$file}->{exec_max} = $elapsed;
			}
			
			$includes->{$file}->{exec_avg} =
				( $includes->{$file}->{exec_avg} * ($includes->{$file}->{exec_cnt}-1)
				  + $elapsed ) / $includes->{$file}->{exec_cnt};
		}
	}

	close IN;

	1;
}

sub print_statistics {
	my $self = shift;
	
	if ( not $self->{data}->{processes} ) {
		print "No statistics data available!<p>\n";
		return;
	}
	
	print "Number of Apache processes: ", $self->{data}->{processes}, "<p>\n";
	
	my %par = $self->{apache_request}->args;
	my $order = $par{o} || 'exec_avg';
	
	$self->print_statistic_part (
		title => "Includes",
		with_load => 0,
		data => $self->{data}->{includes},
		order => $order,
	);
	
	$self->print_statistic_part (
		title => "CIPP Pages",
		data => $self->{data}->{objects},
		order => $order,
	);
	
	return;

	use Data::Dumper;
	print "<font face=courier><pre>";
	print Dumper ($self->{data});
	print "</pre></font>\n";

	1;
}

sub print_statistic_part {
	my $self = shift;
	
	my %par = @_;
	
	my  ($title,  $with_load,  $order,  $data) =
	@par{'title', 'with_load', 'order', 'data'};
	
	print "<p><b>$title</b><p>\n";
	print "<font face=courier size=2><pre>\n";
	
	my ($format, $line, $header);
	if ( $with_load ) {
		$format = " %-40s  %10s  %8s  %8s  %8s  %10s  %8s  %8s  %8s \n";
		$line = " ".("-" x 124)."\n";
		$header = sprintf ($format, "name",
			"exec_cnt", "exec_avg", "exec_min", "exec_max",
			"load_cnt", "load_avg", "load_min", "load_max");
		$format = " %-40s  %10s  %8.3f  %8.3f  %8.3f  %10s  %8.3f  %8.3f  %8.3f \n";
	} else {
		$format = " %-40s  %10s  %8s  %8s  %8s \n";
		$line = " ".("-" x 82)."\n";
		$header = sprintf ($format, "name",
			"exec_cnt", "exec_avg", "exec_min", "exec_max");
		$format = " %-40s  %10s  %8.3f  %8.3f  %8.3f \n";
		$order =~ s/^load_(.*)/exec_$1/;
	}
	
	my $uri = $self->{uri};
	my $refresh = $self->{args}->{refresh};
	$refresh = "&refresh=$refresh" if $refresh;

	$header =~ s! $order ![$order]!;
	$header =~ s!(\w+)!<a href="$uri?o=$1$refresh">$1</a>!g;

	print $header;
	print $line;

	my $num = $order eq 'name' ? 0 : 1;

	my $item;
	foreach my $k ( sort { $num ? $data->{$b}->{$order} <=> $data->{$a}->{$order} :
	                              $data->{$a}->{$order} cmp $data->{$b}->{$order} } keys %{$data} ) {
		$item = $data->{$k};
		if ( $with_load ) {
			printf ($format,
				substr($k,0,40),
				$item->{exec_cnt}, $item->{exec_avg}, $item->{exec_min}, $item->{exec_max},
				$item->{load_cnt}, $item->{load_avg}, $item->{load_min}, $item->{load_max}
			);
		} else {
			printf ($format,
				substr($k,0,40),
				$item->{exec_cnt}, $item->{exec_avg}, $item->{exec_min}, $item->{exec_max}
			);
		}
	}
	
	print $line;

	print "</pre></font>\n";
	
	1;
}
