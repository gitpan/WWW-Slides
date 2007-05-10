use strict;
use warnings;
use Test::More tests => 1; 

my $module;
BEGIN {
   $module = 'WWW::Slides::SlideTracker';
   use_ok($module);
   no strict 'refs';
   diag("Testing $module ${$module . '::VERSION'}");
}
