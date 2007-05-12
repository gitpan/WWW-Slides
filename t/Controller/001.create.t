use strict;
use warnings;

use Test::More tests => 4;
use Test::Exception;

my $module = 'WWW::Slides::Controller';
require_ok($module);

lives_ok { $module->new() }
  'correctly builds without parameters';

my $object;
lives_ok { $object = $module->new(selector => 42) }
  'correctly builds with selector';

# Whatever we pass as selector, it's good
is($object->selector(), 42, 'selector correctly set');
