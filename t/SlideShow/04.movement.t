# vim: filetype=perl :
use strict;
use warnings;

#use Test::More tests => 1; # last test to print
use Test::More 'no_plan';  # substitute with previous line when done
use Test::Exception;

my $module = 'WWW::Slides::SlideShow';
require_ok($module);

my $slide_show = $module->new();
isa_ok($slide_show, 'WWW::Slides::SlideShow');

my %expected = (
   preamble => "<PREAMBLE STUFF HERE>\n<body>\n",
   slides => [
      qq{<div id="slide0">\n</div>\n},
      qq{<div id="slide1">\n</div>\n},
      qq{<div id="slide2">\n</div>\n},
   ],
);
my $input = join '', $expected{preamble}, @{$expected{slides}};
lives_ok { $slide_show->read(\$input) } 'correctly reads from string';

my $first = $slide_show->id_first();
ok(defined $first, 'first slide id is not undefined');

my $first_again = $slide_show->id_first();
is($first_again, $first, 'id_first should be idempotent');

my $next = $slide_show->id_next($first);
isnt($next, $first, 'there was a transition to the next');

my $next_next = $slide_show->id_next($next);
isnt($next_next, $next, 'there was another transition');

my $last = $slide_show->id_last();
ok(defined $last, 'last slide id not undefined');
is($next_next, $last, 'latest transition lead to the last');

my $past_last = $slide_show->id_next($last);
is($past_last, $last, 'forbidden transition past last');

my $pre_first = $slide_show->id_previous($first);
is($pre_first, $first, 'forbidden_transition before first');

my $prev_next_next = $slide_show->id_previous($next_next);
is($prev_next_next, $next, 'going back a little');

my $prev_next = $slide_show->id_previous($next);
is($prev_next, $first, 'going back to the first');
