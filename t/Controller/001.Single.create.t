use strict;
use warnings;

use Test::More tests => 5;
use Test::Exception;
use Test::MockObject;

my $module = 'WWW::Slides::Controller::Single';
require_ok($module);

throws_ok { $module->new() } qr/mandatory.*in_handle/mxs,
  'complains for missing argument out_handle';

my $object;
lives_ok { $object = $module->new(in_handle => 1) }
  'correctly builds with mandatory parameter';

my $selector;
throws_ok { $module->new(in_handle => 1, selector => 1) }
  qr/add.*without/mxs, 'complains for weird selector';

$selector = Test::MockObject->new();
$selector->set_true('add');
lives_ok {
   $object =
     $module->new(in_handle => 1, out_handle => 1, selector => $selector);
  }
  'correctly builds with optional parameters';
