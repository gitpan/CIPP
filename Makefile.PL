# $Id: Makefile.PL,v 1.1.1.1 1999/05/07 13:37:21 joern Exp $

use ExtUtils::MakeMaker;

WriteMakefile(
    'NAME'	=> 'CIPP',
    'VERSION_FROM' => 'CIPP.pm',
    'dist' => {
        COMPRESS => "gzip",
        SUFFIX => "gz"
    }
);
