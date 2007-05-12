use strict;
use warnings;

use Test::More tests => 8;
use Test::MockObject;

#use Test::More tests => 6;
use Test::Exception;

my $module = 'WWW::Slides::Controller::Multiple';
require_ok($module);

my $multiple;
lives_ok { $multiple = $module->new() } 'correctly builds';
ok($multiple->is_alive(), 'object is alive after building up');

my $item = Test::MockObject->new();
$item->set_true(qw( owns execute_commands ));
lives_ok { $multiple->add($item) } 'add lives';
ok(!scalar $item->next_call(), 'set_selector NOT called on item');

lives_ok { $multiple->execute_commands(1, 1) } 'execute_commands lives';
ok($item->called('owns'), 'owns called on item');
ok($item->called('execute_commands'), 'execute_commands called on item');
