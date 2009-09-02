use strict;
use warnings;
use ExtUtils::MakeMaker;

WriteMakefile(
    NAME                => 'HTML::Calendar::Render',
    AUTHOR              => q{Robert Norris <rob@cataclysm.cx>},
    VERSION_FROM        => 'lib/HTML/Calendar/Render.pm',
    ABSTRACT_FROM       => 'lib/HTML/Calendar/Render.pm',
    ($ExtUtils::MakeMaker::VERSION >= 6.3002
      ? ('LICENSE'=> 'perl')
      : ()),
    PL_FILES            => {},
    PREREQ_PM => {
        'Test::More' => 0,
    },
    dist                => { COMPRESS => 'gzip -9f', SUFFIX => 'gz', },
    clean               => { FILES => 'HTML-Calendar-Render-*' },
);
