use strict;
use warnings;

use Test::More tests => 10;

#use Test::More tests => 6;
use Test::Exception;
use Test::MockObject;

my $module = 'WWW::Slides::Controller::Multiple';
require_ok($module);

my $multiple;
lives_ok { $multiple = $module->new() } 'correctly builds';
ok($multiple->is_alive(), 'object is alive after building up');
ok(! $multiple->owns(1), 'negative owns test');

my $item = Test::MockObject->new();
$item->set_true('owns');
my $item2 = Test::MockObject->new();
$item2->set_false('owns');

lives_ok { $multiple->add($item, $item2) } 'multiple add does not complain';
ok(!scalar $item->next_call(), 'set_selector NOT called on item');
ok(!scalar $item2->next_call(), 'set_selector NOT called on item');

ok($multiple->owns(1), 'positive owns test');
lives_ok { $multiple->remove($item) } 'remove lives';
ok(! $multiple->owns(1), 'negative owns test (after removal)');
