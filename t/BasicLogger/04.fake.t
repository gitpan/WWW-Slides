use strict;
use warnings;
use Test::More tests => 12;
use Test::Output;

my $module = 'WWW::Slides::BasicLogger';
require_ok($module);

my $logger = $module->new(fake => 1);
isa_ok($logger, $module, 'constructor ok for silent logger');

my $message  = "ciao";
my $emessage = '';
stderr_is(sub { $logger->debug($message) }, $emessage, 'debug()');
stderr_is(sub { $logger->info($message) },  $emessage, 'info()');
stderr_is(sub { $logger->warn($message) },  $emessage, 'warn()');
stderr_is(sub { $logger->error($message) }, $emessage, 'error()');
stderr_is(sub { $logger->fatal($message) }, $emessage, 'fatal()');
stdout_is(sub { $logger->debug($message) }, $emessage, 'debug()');
stdout_is(sub { $logger->info($message) },  $emessage, 'info()');
stdout_is(sub { $logger->warn($message) },  $emessage, 'warn()');
stdout_is(sub { $logger->error($message) }, $emessage, 'error()');
stdout_is(sub { $logger->fatal($message) }, $emessage, 'fatal()');
