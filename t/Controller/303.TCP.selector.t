# vim: filetype=perl :
use strict;
use warnings;

use Test::More tests => 27; # last test to print
use Test::Exception;
use Test::MockObject;

my $module             = 'WWW::Slides::Controller::TCP';
my $fake_socket_module = 'IO::Socket::INET';
my $fake_single_module = 'WWW::Slides::Controller::Single';

# Prevent loading of IO::Socket
$INC{'IO/Socket.pm'} = '/path/to/somewhere';

require_ok($module);

{
   ok(
      !$fake_socket_module->get_self(),
      "$fake_socket_module still uncalled"
   );

   my $selector = TestSelector->new();

   my $controller;
   is($selector->{add}, 0, 'before first call to selector->add');
   lives_ok {
      $controller = $module->new(port => 1000, selector => $selector);
     }
     'constructor ok with port';
   my $fake_socket = $fake_socket_module->get_self();
   ok($fake_socket, "$fake_socket_module called");
   is($selector->{add}, 1, 'after first call to selector->add');

   ok(
      !$fake_single_module->get_self(),
      "$fake_single_module still uncalled"
   );
   lives_ok { $controller->execute_commands($fake_socket, 1); }
     'execute_commands lives for door';
   my $fake_single = $fake_single_module->get_self();
   ok($fake_single, "$fake_single_module called");
   ok($fake_single->called('set_selector'), 
      "$fake_single_module called for set_selector");

   is($selector->{remove}, 0, 'before call to selector->remove');
   lives_ok { $controller->release_selector() } 'release_selector lives';
   is($selector->{remove}, 1, 'after call to selector->remove');
   ok($fake_single->called('release_selector'),
      "$fake_single_module called for release_selector");

   $fake_socket_module->reset();
   $fake_single_module->reset();
}

{
   ok(
      !$fake_socket_module->get_self(),
      "$fake_socket_module still uncalled"
   );

   my $selector = TestSelector->new();

   my $controller;
   lives_ok {
      $controller = $module->new(port => 1000);
     }
     'constructor ok with port';
   my $fake_socket = $fake_socket_module->get_self();
   ok($fake_socket, "$fake_socket_module called");

   is($selector->{add}, 0, 'before first call to selector->add');
   $controller->set_selector($selector);
   is($selector->{add}, 1, 'after first call to selector->add');

   ok(
      !$fake_single_module->get_self(),
      "$fake_single_module still uncalled"
   );
   lives_ok { $controller->execute_commands($fake_socket, 1); }
     'execute_commands lives for door';
   my $fake_single = $fake_single_module->get_self();
   ok($fake_single, "$fake_single_module called");
   ok($fake_single->called('set_selector'), 
      "$fake_single_module called for set_selector");

   is($selector->{remove}, 0, 'before call to selector->remove');
   lives_ok { $controller->release_selector() } 'release_selector lives';
   is($selector->{remove}, 1, 'after call to selector->remove');
   ok($fake_single->called('release_selector'),
      "$fake_single_module called for release_selector");

   $fake_socket_module->reset();
   $fake_single_module->reset();
}


BEGIN {

   package IO::Socket::INET;
   {
      use Test::MockObject;
      my $self;

      sub init_self {
         $self = Test::MockObject->new();
         $self->set_always('accept' => Test::MockObject->new());
         return $self;
      }

      sub new {
         init_self() unless $self;
         return $self;
      }

      sub get_self {
         return $self;
      }

      sub reset {
         $self = undef;
      }
   }

   package WWW::Slides::Controller::Single;
   {
      use Test::MockObject;
      my $self;

      sub init_self {
         $self = Test::MockObject->new();
         $self->set_true(qw( owns execute_commands 
            set_selector release_selector shut_down ));
         return $self;
      }

      sub new {
         init_self() unless $self;
         return $self;
      }

      sub get_self {
         return $self;
      }

      sub reset {
         $self = undef;
      }
   }

   # I need the following because Test::MockObject does not allow
   # mocking of 'remove' methods :/
   package TestSelector;
   sub new { return bless {add => 0, remove => 0}, shift }
   sub add    { return shift->{add}++ }
   sub remove { return shift->{remove}++ }
   1;
} ## end BEGIN
