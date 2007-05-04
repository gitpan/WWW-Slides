use strict;
use warnings;
use Test::More tests => 4;

my $module = 'WWW::Slides::BasicLogger';
require_ok($module);

isa_ok($module->new(), $module, 'object correctly created');
isa_ok($module->new(fake => 1), $module, 'fake parameter accepted');
isa_ok($module->new(channel => \*STDOUT),
   $module, 'channel parameter accepted');
