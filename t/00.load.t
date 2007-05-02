use strict;
use warnings;
use Test::More 'no_plan';

BEGIN {
   diag('Testing inclusions');
   for my $module (map { "WWW::Slides::$_" }
     qw( Talk )) {
      use_ok($module);
      no strict 'refs';
      diag("Testing $module ${$module . '::VERSION'}");
   }
}

