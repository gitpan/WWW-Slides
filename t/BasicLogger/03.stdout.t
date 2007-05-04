# vim: filetype=perl :
use strict;
use warnings;

use Test::More tests => 7; # last test to print
use Test::Output;

my $module = 'WWW::Slides::BasicLogger';
require_ok($module);

my $logger = $module->new(channel => \*STDOUT);
isa_ok($logger, $module, 'constructor ok');

my $message  = "ciao";
my $emessage = $message . "\n";
stdout_is(sub { $logger->debug($message) }, $emessage, 'debug()');
stdout_is(sub { $logger->info($message) },  $emessage, 'info()');
stdout_is(sub { $logger->warn($message) },  $emessage, 'warn()');
stdout_is(sub { $logger->error($message) }, $emessage, 'error()');
stdout_is(sub { $logger->fatal($message) }, $emessage, 'fatal()');
