use strict;
use warnings;
use Test::More tests => 6;
use Test::Exception;
use File::Basename qw( dirname );

use lib dirname(__FILE__);
use ClientTest qw( start_child_server echo );

my $module = 'WWW::Slides::Client::TCP';
require_ok($module);

# Start a TCP server in the child
my $port = 50607;
lives_ok {start_child_server($port, \&echo)} 'test server creation';

my $object;
lives_ok { $object = $module->new(port => $port) }
   'correctly builds with parameter port and running server';

my $message = 'ciao';
ok($object->raw_send($message), 'raw_send');
is($object->receive(), $message, 'receive');
is($object->send_command($message), "$message\n", 'send_command');
