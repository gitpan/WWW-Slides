# vim: filetype=perl :
use strict;
use warnings;

#use Test::More tests => 1; # last test to print
use Test::More 'no_plan';  # substitute with previous line when done
use Test::Exception;

my $module = 'WWW::Slides::Controller';
require_ok($module);

my $object;
lives_ok { $object = $module->new() }
  'correctly builds without parameters';

# Whatever we pass as selector, it's good
lives_ok { $object->set_selector(42) } 'tolerates set_selector()';
is($object->selector(), 42, 'selector correctly set');
lives_ok { $object->release_selector(42) } 'tolerates set_selector()';

lives_ok { $object->shut_down(42) } 'tolerates shut_down()';
