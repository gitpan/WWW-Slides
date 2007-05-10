use strict;
use warnings;

use Test::More tests => 5;
use Test::Exception;
use Test::MockObject;

my $module = 'WWW::Slides::Controller::Single';
require_ok($module);

my $handle = Test::MockObject->new();
my $object;
lives_ok {
   $object = $module->new(in_handle => $handle);
  }
  'correctly builds with mandatory parameters';

ok($object->owns($handle), 'object owns fake handle');
ok(!$object->owns(Test::MockObject->new()),
   'object disowns random object');
ok(!$object->owns(undef), 'object disowns random undef');
