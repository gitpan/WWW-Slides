# vim: filetype=perl :
use strict;
use warnings;

use Test::More tests => 7; # last test to print
use Test::Exception;

my $module             = 'WWW::Slides::Controller::UDP';
my $fake_socket_module = 'IO::Socket::INET';
my $fake_single_module = 'WWW::Slides::Controller::Single';

# Prevent loading of IO::Socket
$INC{'IO/Socket.pm'} = '/path/to/somewhere';

require_ok($module);

throws_ok { $module->new() } qr/missing.*port/msxi,
  'complains about missing port';

ok(!$fake_socket_module->get_self(), "$fake_socket_module still uncalled");

my $controller;
lives_ok { $controller = $module->new(port => 1000); }
  'constructor ok with port';

ok($fake_socket_module->get_self(), "$fake_socket_module called");

$fake_socket_module->reset();
$fake_socket_module->set_block(1);
throws_ok { $module->new(port => 1000) } qr/cannot create socket/ms,
   'constructor bails out when cannot open door socket';
ok(!$fake_socket_module->get_self(), "$fake_socket_module still uncalled");

BEGIN {

   package IO::Socket::INET;
   {
      use Test::MockObject;
      my $self;
      my $block;

      sub init_self {
         $self = Test::MockObject->new();
         $self->set_always('accept' => Test::MockObject->new());
         return $self;
      }

      sub new {
         init_self() unless $self || $block;
         return $self;
      }

      sub get_self {
         return $self;
      }

      sub reset {
         $self = undef;
         $block = undef;
      }
      
      sub set_block {
         $block = $_[1];
      }
   }

   1;
} ## end BEGIN
