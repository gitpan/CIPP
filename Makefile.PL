# $Id: Makefile.PL,v 1.2 2001/03/18 18:57:47 joern Exp $

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
