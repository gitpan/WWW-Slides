use strict;
use warnings;

use Test::More tests => 3;
use Test::Exception;
use Test::MockObject;

my $module = 'WWW::Slides::Controller::Single';
require_ok($module);

my $object;
lives_ok {
   $object = $module->new(in_handle => 1);
  }
  'correctly builds with mandatory parameter';

ok($object->is_alive(), 'object is alive');
