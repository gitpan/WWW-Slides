use strict;
use warnings;

use Test::More tests => 10;
use Test::Exception;

my $module = 'WWW::Slides::Controller::Multiple';
require_ok($module);

my $object;
lives_ok { $object = $module->new() } 'correctly builds';
ok($object->is_alive(), 'object is alive after building up');

lives_ok { $object->set_selector(24) } 'set_selector() lives';
is($object->selector(), 24, 'selector value correctly set');
lives_ok { $object->release_selector() } 'release_selector() lives';

# Using an extremely fake selector here!
$object = undef;
lives_ok { $object = $module->new(selector => 42) }
  'correctly builds with optional parameter selector';
ok($object->is_alive(), 'object is alive after building up');
is($object->selector(), 42, 'selector value correctly set in constructor');

lives_ok { $object->shut_down() } 'shut_down() lives';
