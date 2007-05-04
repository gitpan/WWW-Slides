# vim: filetype=perl :
use strict;
use warnings;

use Test::More tests => 7; # last test to print
use Test::Output;

my $module = 'WWW::Slides::BasicLogger';
require_ok($module);

my $logger = $module->new();
isa_ok($logger, $module, 'default constructor ok');

my $message  = "ciao";
my $emessage = $message . "\n";
stderr_is(sub { $logger->debug($message) }, $emessage, 'debug()');
stderr_is(sub { $logger->info($message) },  $emessage, 'info()');
stderr_is(sub { $logger->warn($message) },  $emessage, 'warn()');
stderr_is(sub { $logger->error($message) }, $emessage, 'error()');
stderr_is(sub { $logger->fatal($message) }, $emessage, 'fatal()');
