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

is($slide_show->get_preamble(), $expected{preamble}, 'preamble read ok');

like($slide_show->get_ping(), qr/<!-- .* -->/mxs, 'ping is a comment');

my $n = $slide_show->id_first();
ok(defined $n, 'first slide id is not undefined');

my $m = $slide_show->id_first();
is($n, $m, 'id_first should be idempotent');

for my $i ( 0 .. 2 ) {
   is($slide_show->get_slide($n), $expected{slides}[$i], "slide $i");
   like($slide_show->get_show_div($n),
      qr/\#slide$i .* display\s*:\s*block/mxs, 'get_show_div sort of good');
   like($slide_show->get_hide_div($n),
      qr/\#slide$i .* display\s*:\s*none/mxs, 'get_hide_div sort of good');
   $n = $slide_show->id_next($n);
}

my $last = $slide_show->id_last();
is($n, $last, 'should be on the last slide after the loop');
