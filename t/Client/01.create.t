use strict;
use warnings;
use Test::More tests => 5;
use Test::Exception;

my $module = 'WWW::Slides::Client::Base';
require_ok($module);

throws_ok { $module->new() } qr/mandatory.*(in|out)_handle/mxs,
  'complains for missing arguments';
throws_ok { $module->new(out_handle => 1) } qr/mandatory.*in_handle/mxs,
  'complains for missing argument in_handle';
throws_ok { $module->new(in_handle => 1) } qr/mandatory.*out_handle/mxs,
  'complains for missing argument out_handle';

my $object;
lives_ok { $object = $module->new(in_handle => 1, out_handle => 1) }
   'correctly builds with both parameters';
