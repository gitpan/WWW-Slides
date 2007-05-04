use strict;
use warnings;
use Test::More tests => 5;
use Test::Exception;
use File::Basename qw( dirname );

use lib dirname(__FILE__);
use ClientTest qw( start_child_server );

my $module = 'WWW::Slides::Client::TCP';
require_ok($module);

throws_ok { $module->new() } qr/mandatory.*port/mxs,
  'complains for missing argument port';

my $port = 50607;
throws_ok { $module->new(port => $port) } qr/no\s+socket/mxs,
  'complains for missing server';

# Start a TCP server in the child
lives_ok {start_child_server($port)} 'test server creation';

my $object;
lives_ok { $object = $module->new(port => $port) }
   'correctly builds with parameter port and running server';
