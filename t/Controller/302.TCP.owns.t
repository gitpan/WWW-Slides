# vim: filetype=perl :
use strict;
use warnings;

use Test::More tests => 9; # last test to print
use Test::Exception;

my $module             = 'WWW::Slides::Controller::TCP';
my $fake_socket_module = 'IO::Socket::INET';
my $fake_single_module = 'WWW::Slides::Controller::Single';

# Prevent loading of IO::Socket
$INC{'IO/Socket.pm'} = '/path/to/somewhere';

require_ok($module);

ok(!$fake_socket_module->get_self(), "$fake_socket_module still uncalled");
my $controller;
lives_ok { $controller = $module->new(port => 1000); }
  'constructor ok with port';
my $fake_socket = $fake_socket_module->get_self();
ok($fake_socket, "$fake_socket_module called");

ok(!$fake_single_module->get_self(), "$fake_single_module still uncalled");
lives_ok { $controller->execute_commands($fake_socket, 1); }
   'execute_commands lives for door';
my $fake_single = $fake_single_module->get_self();
ok($fake_single, "$fake_single_module called");

ok($controller->owns($fake_socket), 'owns its door');
ok($controller->owns($fake_single), 'owns its sub-controller handle');

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
   }

   package WWW::Slides::Controller::Single;
   {
      use Test::MockObject;
      my $self;

      sub init_self {
         $self = Test::MockObject->new();
         $self->set_true(qw( owns execute_commands ));
         return $self;
      }

      sub new {
         init_self() unless $self;
         return $self;
      }

      sub get_self {
         return $self;
      }
   }
   1;
} ## end BEGIN
