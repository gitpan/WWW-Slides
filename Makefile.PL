use strict;
use warnings;
use ExtUtils::MakeMaker;

WriteMakefile(
   NAME          => 'WWW::Slides',
   AUTHOR        => 'Flavio Poletti <flavio [at] polettix [dot] it>',
   VERSION_FROM  => 'lib/WWW/Slides.pm',
   ABSTRACT_FROM => 'lib/WWW/Slides.pm',
   PL_FILES      => {},
   PREREQ_PM     => {
      'Test::More'        => 0,
      'version'           => 0,
      'Carp'              => 0,
      'Digest::MD5'       => 0,
      'English'           => 0,
      'HTTP::Response'    => 0,
      'IO::Handle'        => 0,
      'IO::Select'        => 0,
      'IO::Socket'        => 0,
      'Object::InsideOut' => 0,
      'Socket'            => 0,
      'Test::Exception'   => 0,
      'Test::MockObject'  => 0,
   },
   dist  => {COMPRESS => 'gzip -9f', SUFFIX => 'gz',},
   clean => {FILES    => 'WWW-Slides-*'},
   test  => {TESTS    => join(' ',   map    { glob } qw( t/*.t t/*/*.t))},
);
