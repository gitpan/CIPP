# $Id: Makefile.PL,v 1.1 2001/10/24 18:54:43 joern Exp $

use ExtUtils::MakeMaker;

WriteMakefile(
    'NAME'	=> 'CIPP',
    'VERSION_FROM' => 'lib/CIPP.pm',
    'dist' => {
        COMPRESS => "gzip",
        SUFFIX => "gz",
	POSTOP => "mv *.tar.gz dist",
    }
);
