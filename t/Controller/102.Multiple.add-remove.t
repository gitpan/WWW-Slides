use strict;
use warnings;

use Test::More tests => 18;

#use Test::More tests => 6;
use Test::Exception;
use Test::MockObject;

my $module = 'WWW::Slides::Controller::Multiple';
require_ok($module);

my $multiple;
lives_ok { $multiple = $module->new() } 'correctly builds';
ok($multiple->is_alive(), 'object is alive after building up');

my $item = Test::MockObject->new();
$item->set_true(qw( set_selector release_selector ));

lives_ok { $multiple->add($item) } 'add lives w/out selector';
ok(!scalar $item->next_call(), 'set_selector NOT called on item');
lives_ok { $multiple->remove($item) } 'remove lives w/out selector';

lives_ok { $multiple->add($item) } 're-add lives w/out selector';
my $selector = Test::MockObject->new();
lives_ok { $multiple->set_selector($selector); } 'set_selector lives';
is(scalar $item->next_call(),
   'set_selector', 'set_selector called on item');

lives_ok { $multiple->release_selector($selector) }
  'release_selector lives';
is(scalar $item->next_call(),
   'release_selector', 'release_selector called on item');

lives_ok { $multiple->set_selector($selector); } 'set_selector lives';
is(scalar $item->next_call(),
   'set_selector', 'set_selector re-called on item');

lives_ok { $multiple->remove($item) } 'remove lives';
is(scalar $item->next_call(),
   'release_selector', 'release_selector called on removed item');

my $item2 = Test::MockObject->new();
$item2->set_true(qw( set_selector release_selector ));
lives_ok { $multiple->add($item2) } 'add lives for new item';
is(scalar $item2->next_call(),
   'set_selector', 'set_selector called on new item');
ok(!scalar $item->next_call(), 'set_selector NOT called on removed item');
