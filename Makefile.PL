use 5.006;
use strict; use warnings;
use ExtUtils::MakeMaker;

WriteMakefile(
    NAME               => 'Games::Domino',
    AUTHOR             => q{Mohammad S Anwar <mohammad.anwar@yahoo.com>},
    VERSION_FROM       => 'lib/Games/Domino.pm',
    ABSTRACT_FROM      => 'lib/Games/Domino.pm',
    LICENSE            => 'artistic_2',
    PL_FILES           => {},
    MIN_PERL_VERSION   => 5.006,
    CONFIGURE_REQUIRES => {
        'ExtUtils::MakeMaker' => 0,
    },
    BUILD_REQUIRES => {
        'Test::More' => 0,
    },
    PREREQ_PM => {
        'Attribute::Memoize' => 1.01,
        'List::Util'         => 1.19,
        'Moo'                => 0,
        'namespace::clean'   => 0,
    },
    dist  => { COMPRESS => 'gzip -9f', SUFFIX => 'gz', },
    clean => { FILES => 'Games-Domino-*' },
    (eval { ExtUtils::MakeMaker->VERSION(6.46) } ? (META_MERGE => {
        'meta-spec' => { version => 2 },
        resources => {
            repository => {
                type => 'git',
                url  => 'https://github.com/Manwar/Games-Domino.git',
                web  => 'https://github.com/Manwar/Games-Domino',
            },
        }})
     : ()
    ),
);
