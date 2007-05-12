# vim: filetype=perl :
use strict;
use warnings;

use Test::More tests => 2;    # last test to print
use Test::Exception;

my $module = 'WWW::Slides::Controller::STDIO';
require_ok($module);

lives_ok { $module->new() } 'correctly builds';
