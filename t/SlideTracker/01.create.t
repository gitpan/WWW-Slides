use strict;
use warnings;
use Test::More 'no_plan';
use Test::Exception;
use Test::MockObject;

my $module = 'WWW::Slides::SlideTracker';
require_ok($module);

throws_ok { $module->new() } qr/mandatory/msx,
  'balks for incomplete constructor';

my $tracker;
lives_ok {
   $tracker =
     $module->new(
      {slide_show => 1, current => 0});
  }
  'constructor ok with all mandatory parameters';
