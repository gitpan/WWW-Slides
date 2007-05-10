use strict;
use warnings;

use Test::More tests => 13;
use Test::Exception;
use Test::MockObject;

my $module = 'WWW::Slides::Controller::Single';
require_ok($module);

{
   my $object;
   lives_ok {
      $object = $module->new(in_handle => 1);
     }
     'correctly builds with mandatory parameter';

   ok($object->is_alive(), 'object is alive');

   my $selector = TestSelector->new();    # See end of this file

   lives_ok { $object->set_selector($selector); } 'set_selector call';
   is($selector->{add}, 1, 'selector correctly invoked for addition');

   lives_ok { $object->release_selector() } 'release_selector call';
   is($selector->{remove}, 1, 'selector correctly invoked for removal');
}

{
   my $selector = TestSelector->new();       # See end of this file
   my $handle   = Test::MockObject->new();
   my $closed   = 0;
   $handle->mock('close' => sub { ++$closed });
   my $object;
   lives_ok {
      $object = $module->new(in_handle => $handle, selector => $selector);
     }
     'correctly builds with mandatory and optional parameters';

   ok($object->is_alive(), 'object is alive');

   is($selector->{add}, 1,
      'selector correctly invoked for addition during construction');

   lives_ok { $object->shut_down() } 'shut_down';
   is($selector->{remove}, 1,
      'selector correctly invoked for removal during shutdown');
   is($closed, 1, 'handle was closed');
}

# I need the following because Test::MockObject does not allow
# mocking of 'remove' methods :/
package TestSelector;
sub new { return bless {add => 0, remove => 0}, shift }
sub add    { return shift->{add}++ }
sub remove { return shift->{remove}++ }
1;
