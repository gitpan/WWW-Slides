use strict;
use warnings;
use Module::Build;

my $builder = Module::Build->new(
   module_name       => 'WWW::Slides',
   license           => 'perl',
   dist_author       => 'Flavio Poletti <flavio [at] polettix [dot] it>',
   dist_version_from => 'VERSION',
   requires          => {
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
      'Test::Output'      => 0,
      'File::Basename'    => 0,
   },
   add_to_cleanup => ['WWW-Slides-*'],
   test_files     => 't/*.t t/*/*.t',
);

$builder->create_build_script();
