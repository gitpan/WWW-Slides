use strict;
use warnings;
use Test::More 'no_plan';

my $module;
BEGIN {
   $module = 'WWW::Slides::SlideShow';
   use_ok($module);
   no strict 'refs';
   diag("Testing $module ${$module . '::VERSION'}");
}
