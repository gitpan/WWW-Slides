# vim: filetype=perl :
use strict;
use warnings;

use Test::More tests => 3; # last test to print

my $module = 'WWW::Slides::SlideShow';
require_ok($module);

my $slide_show = $module->new();
isa_ok($slide_show, 'WWW::Slides::SlideShow');

can_ok($slide_show, qw(
      read filename add_headers 
      get_preamble get_slide get_show_div get_hide_div get_ping
      validate_slide_id id_first id_last id_next id_previous
   )
);
